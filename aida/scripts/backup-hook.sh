#!/bin/bash
# Aida PreToolUse backup hook (Edit/Write/MultiEdit/NotebookEdit).
# Snapshots the target file into /config/aida/backups BEFORE it is modified,
# so every AI edit is one command away from being reverted. Never blocks.

[ "${AIDA_AUTO_BACKUP}" = "false" ] && exit 0

INPUT=$(cat)
file_path=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only back up existing files that live under /config.
if [ -n "$file_path" ] && [ -f "$file_path" ]; then
    case "$file_path" in
        /config/*)
            backup_root="/config/aida/backups"
            ts=$(date '+%Y%m%d-%H%M%S')
            rel="${file_path#/config/}"
            dest="${backup_root}/${ts}/${rel}"
            mkdir -p "$(dirname "$dest")"
            cp -p "$file_path" "$dest" 2>/dev/null || true
            ;;
    esac
fi

exit 0
