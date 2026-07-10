#!/usr/bin/with-contenv bashio
# Register ha-mcp (Home Assistant MCP Server) so Aida can control entities,
# automations, scripts and more via natural language.
# Repository: https://github.com/homeassistant-ai/ha-mcp
#
# We write the MCP server config DIRECTLY into Claude Code's ~/.claude.json
# instead of calling `claude mcp add`. The CLI can block on first-run prompts;
# a direct JSON write is instant, deterministic, and never hangs startup.
#
# `--with numpy<2`: ha-mcp -> textdistance -> numpy. NumPy 2.x wheels require
# x86-64-v2 CPU instructions, which older/VM CPUs (e.g. the default kvm64 model)
# don't have, so ha-mcp crashes on import. NumPy 1.x uses the baseline x86-64
# ISA and loads everywhere.

configure_ha_mcp_server() {
    local enable_ha_mcp
    enable_ha_mcp=$(bashio::config 'enable_ha_mcp' 'true')
    if [ "$enable_ha_mcp" != "true" ]; then
        bashio::log.info "ha-mcp integration is disabled in configuration."
        return 0
    fi
    if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
        bashio::log.warning "SUPERVISOR_TOKEN unavailable — skipping ha-mcp."
        return 0
    fi
    if ! command -v uvx >/dev/null 2>&1; then
        bashio::log.warning "uvx not found — skipping ha-mcp."
        return 0
    fi

    local claude_json="${HOME}/.claude.json"
    local tmp
    tmp=$(mktemp)

    # Merge a user-scoped "home-assistant" MCP server into the existing config.
    if jq -n --arg token "${SUPERVISOR_TOKEN}" \
        --slurpfile existing <(cat "$claude_json" 2>/dev/null || echo '{}') '
        ($existing[0] // {}) as $c |
        $c | .mcpServers = (($c.mcpServers // {}) + {
          "home-assistant": {
            "type": "stdio",
            "command": "uvx",
            "args": ["--index-strategy", "unsafe-best-match", "--with", "numpy<2", "ha-mcp@3.5.1"],
            "env": {
              "HOMEASSISTANT_URL": "http://supervisor/core",
              "HOMEASSISTANT_TOKEN": $token
            }
          }
        })
    ' > "$tmp" 2>/dev/null && mv "$tmp" "$claude_json"; then
        bashio::log.info "ha-mcp registered — Aida can act on Home Assistant after sign-in."
    else
        rm -f "$tmp"
        bashio::log.warning "Could not register ha-mcp; continuing without it."
    fi
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_ha_mcp_server
fi
