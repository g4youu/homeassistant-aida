#!/bin/bash
# Aida HA context — generates a CLAUDE.md so every session knows this specific
# Home Assistant install (system info, entity summary, add-ons, recent errors).
# Claude Code auto-loads CLAUDE.md from HOME.

SUPERVISOR_URL="http://supervisor"
OUTPUT_FILE="${HOME}/CLAUDE.md"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        --help)
            echo "Usage: aida-context [--output FILE]"
            echo "Writes a Home Assistant context file that Aida auto-loads."
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

api() { curl -s -m 10 -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" "${SUPERVISOR_URL}/$1" 2>/dev/null; }
core() { api "core/api/$1"; }

if [ -z "$SUPERVISOR_TOKEN" ]; then
    echo "Error: SUPERVISOR_TOKEN not set (run inside the add-on)." >&2
    exit 1
fi
for c in curl jq; do command -v "$c" >/dev/null || { echo "Error: $c required." >&2; exit 1; }; done

tmp=$(mktemp "${OUTPUT_FILE}.XXXXXX")
{
    echo "# Home Assistant Context (for Aida)"
    echo ""
    echo "> Auto-generated. Run \`aida-context\` to refresh. Updated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "## System"
    echo ""
    core_info=$(api "core/info"); host_info=$(api "host/info"); cfg=$(core "config")
    ver=$(echo "$core_info" | jq -r '.data.version // empty')
    machine=$(echo "$core_info" | jq -r '.data.machine // empty')
    os=$(echo "$host_info" | jq -r '.data.operating_system // empty')
    loc=$(echo "$cfg" | jq -r '.location_name // empty')
    tz=$(echo "$cfg" | jq -r '.time_zone // empty')
    [ -n "$ver" ] && echo "- **Home Assistant**: $ver"
    [ -n "$machine" ] && echo "- **Machine**: $machine"
    [ -n "$os" ] && echo "- **OS**: $os"
    [ -n "$loc" ] && echo "- **Location**: $loc"
    [ -n "$tz" ] && echo "- **Timezone**: $tz"

    echo ""
    echo "## Entities"
    echo ""
    states=$(core "states")
    if echo "$states" | jq -e '.' >/dev/null 2>&1; then
        total=$(echo "$states" | jq 'length')
        echo "| Domain | Count |"
        echo "|--------|-------|"
        echo "$states" | jq -r '[.[].entity_id|split(".")[0]]|group_by(.)|map({d:.[0],c:length})|sort_by(-.c)|.[]|"| \(.d) | \(.c) |"'
        echo ""
        echo "**Total: ${total} entities**"
    else
        echo "Unable to retrieve entity states."
    fi

    echo ""
    echo "## Installed Add-ons"
    echo ""
    api "addons" | jq -r '.data.addons[]|select(.installed==true)|"- \(.name) v\(.version) (\(.state))"' 2>/dev/null | sort

    echo ""
    echo "## Recent Errors"
    echo ""
    errlog=$(core "error_log")
    if [ -n "$errlog" ] && [ "$errlog" != "\"\"" ]; then
        echo '```'
        echo "$errlog" | tail -20 | cut -c1-200
        echo '```'
    else
        echo "No recent errors."
    fi

    cat <<'REF'

## How to help

You are Aida, an assistant embedded in this Home Assistant install. You can:
- Read/edit files under `/config` (backed up automatically before edits)
- Control Home Assistant through the `home-assistant` MCP tools
- Call the Supervisor API: `curl -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/core/api/states`

Protected entities may be blocked by the safety guard. Prefer proposing changes
and explaining them when running in assisted mode.
REF
} > "$tmp"

chmod 644 "$tmp"
mv "$tmp" "$OUTPUT_FILE"
echo "Aida context written to ${OUTPUT_FILE}" >&2
