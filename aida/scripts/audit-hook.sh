#!/bin/bash
# Aida PostToolUse audit hook. Appends a JSON line describing every tool the
# assistant used, so there is an answerable record of what the AI did.

[ "${AIDA_AUDIT_LOG}" = "false" ] && exit 0

INPUT=$(cat)
log_file="/config/aida/audit.log"
mkdir -p "$(dirname "$log_file")"

ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
tool=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
summary=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null | cut -c1-500)

printf '{"ts":"%s","mode":"%s","tool":"%s","input":%s}\n' \
    "$ts" "${AIDA_MODE:-unknown}" "$tool" "${summary:-{}}" >> "$log_file" 2>/dev/null || true

exit 0
