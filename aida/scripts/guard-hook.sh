#!/bin/bash
# Aida PreToolUse guard hook.
# Reads the tool call as JSON on stdin and enforces the safety policy that
# the model cannot talk its way around:
#   - hard denylist of catastrophic shell commands
#   - read-only mode blocks all mutating tools
#   - entity denylist blocks control of protected domains/entities
# Exit 0 = allow (defer to settings.json allow/ask/deny).
# Exit 2 = block (reason on stderr is shown to the model).

INPUT=$(cat)

tool_name=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
command=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
file_path=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
# Flatten all tool_input values so we can scan mcp args, service data, etc.
payload=$(echo "$INPUT" | jq -r '[.tool_input // {} | .. | strings] | join(" ")' 2>/dev/null)
scan="${command} ${file_path} ${payload}"

block() {
    echo "🛡️  Aida guard blocked this action: $1" >&2
    exit 2
}

# --- 1. Hard denylist (always blocked, any mode) ---
case "$command" in
    *"rm -rf /"*|*"rm -rf /*"*|*":(){:|:&};:"*|*"mkfs"*|*"> /dev/sda"*)
        block "catastrophic command pattern" ;;
esac
# Never let edits escape the HA config / add-on data areas.
if [ -n "$file_path" ]; then
    case "$file_path" in
        /config/*|/data/*|/tmp/*) : ;;
        *) block "write outside /config and /data is not permitted ($file_path)" ;;
    esac
fi

# --- 2. Read-only mode: no mutations at all ---
if [ "${AIDA_MODE}" = "read-only" ]; then
    case "$tool_name" in
        Edit|Write|MultiEdit|NotebookEdit)
            block "read-only mode is active — editing files is disabled" ;;
    esac
    # Block obviously mutating shell + HA service calls
    if echo "$scan" | grep -qiE '(^|[^a-z])(rm|mv|cp|apk add|pip install|systemctl|reboot|shutdown)([^a-z]|$)|services/[a-z_]+/(turn_on|turn_off|toggle|set_|call|delete|create)|"?(turn_on|turn_off|toggle|call_service|set_state|delete|create)"?'; then
        block "read-only mode is active — this looks like a state-changing action"
    fi
fi

# --- 3. Entity denylist (all modes) ---
if [ -n "${AIDA_ENTITY_DENYLIST}" ]; then
    IFS=',' read -ra denied <<< "${AIDA_ENTITY_DENYLIST}"
    for e in "${denied[@]}"; do
        e=$(echo "$e" | xargs)   # trim
        [ -z "$e" ] && continue
        # Match "domain." or a full entity id, but only when paired with a
        # control verb so we don't block harmless reads/mentions.
        if echo "$scan" | grep -qiE "(^|[^a-z0-9_.])${e}([._]|\b)" \
           && echo "$scan" | grep -qiE '(turn_on|turn_off|toggle|call_service|set_|open|close|unlock|lock|arm|disarm|delete)'; then
            block "entity/domain '${e}' is on the protected denylist"
        fi
    done
fi

exit 0
