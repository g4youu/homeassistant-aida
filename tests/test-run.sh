#!/usr/bin/env bash
# Lightweight test suite for Aida's shell logic — plain bash + jq, no framework,
# so it runs locally and in CI. Covers the pieces that caused real breakage:
# CPU x86-64-v2 detection, the .claude.json onboarding merge, and the ha-mcp
# numpy<2 pin that keeps Home Assistant control working on older/VM CPUs.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_SH="${ROOT}/aida/run.sh"
HA_MCP="${ROOT}/aida/scripts/setup-ha-mcp.sh"

pass=0; fail=0
ok(){ printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
no(){ printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

# Stub bashio so sourcing run.sh never needs the real thing.
bashio::log.info(){ :; }; bashio::log.warning(){ :; }; bashio::log.error(){ :; }
bashio::config(){ printf '%s' "${2:-}"; }
bashio::config.has_value(){ return 1; }
bashio::addon.version(){ echo test; }
export AIDA_SOURCE_ONLY=1
# shellcheck source=/dev/null
source "$RUN_SH"

echo "== functions are defined after sourcing =="
for fn in cpu_supports_x86_64_v2 setup_claude_runtime install_pinned_claude \
          run_diagnostics init_environment setup_ha_mcp main; do
    if declare -F "$fn" >/dev/null; then ok "defined: $fn"; else no "defined: $fn"; fi
done

echo "== cpu_supports_x86_64_v2 =="
v2=$(mktemp); non=$(mktemp)
printf 'flags\t: fpu sse4_1 sse4_2 popcnt avx avx2\n' > "$v2"
printf 'flags\t: fpu de pse tsc cx16\n' > "$non"
if cpu_supports_x86_64_v2 "$v2"; then ok "detects a v2 CPU"; else no "detects a v2 CPU"; fi
if ! cpu_supports_x86_64_v2 "$non"; then ok "rejects a non-v2 CPU"; else no "rejects a non-v2 CPU"; fi
rm -f "$v2" "$non"

echo "== .claude.json onboarding merge (mirrors init_environment) =="
merge(){
    printf '{"hasCompletedOnboarding":true,"theme":"dark","mcpServers":{"x":{}}}' | \
    jq -n --argjson signedin "$1" --slurpfile existing /dev/stdin '
        ($existing[0] // {}) as $e | $e
        | .theme = ($e.theme // "dark")
        | (if $signedin then .hasCompletedOnboarding = true else del(.hasCompletedOnboarding) end)
        | .projects = (($e.projects // {}) * {"/config": (($e.projects["/config"] // {}) + {hasTrustDialogAccepted: true, projectOnboardingSeenCount: 1})})'
}
out_out=$(merge false); out_in=$(merge true)
[ "$(jq 'has("hasCompletedOnboarding")' <<<"$out_out")" = false ] && ok "signed-out drops onboarding flag" || no "signed-out drops onboarding flag"
[ "$(jq -r '.hasCompletedOnboarding' <<<"$out_in")" = true ]    && ok "signed-in sets onboarding flag"   || no "signed-in sets onboarding flag"
[ "$(jq 'has("mcpServers")' <<<"$out_out")" = true ]            && ok "preserves existing mcpServers"    || no "preserves existing mcpServers"
[ "$(jq -r '.projects["/config"].hasTrustDialogAccepted' <<<"$out_out")" = true ] && ok "accepts /config trust dialog" || no "accepts /config trust dialog"

echo "== ha-mcp registration pins numpy<2 (guards the x86-64-v2 fix) =="
grep -q 'numpy<2' "$HA_MCP" && ok "setup-ha-mcp.sh keeps --with numpy<2" || no "setup-ha-mcp.sh keeps --with numpy<2"
grep -q 'ha-mcp@'  "$HA_MCP" && ok "setup-ha-mcp.sh still installs ha-mcp" || no "setup-ha-mcp.sh still installs ha-mcp"

echo ""
echo "RESULT: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
