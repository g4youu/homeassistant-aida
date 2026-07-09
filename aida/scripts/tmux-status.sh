#!/bin/bash
# Aida tmux status line: sign-in state, HA connection, safety mode, time.

sign_in() {
    local cfg="${ANTHROPIC_CONFIG_DIR:-$HOME/.config/claude}"
    if [ -n "$ANTHROPIC_API_KEY" ] || [ "$CLAUDE_CODE_USE_BEDROCK" = "1" ] || \
       [ "$CLAUDE_CODE_USE_VERTEX" = "1" ] || \
       [ -f "$cfg/.credentials.json" ] || [ -f "$cfg/credentials.json" ]; then
        echo "#[fg=colour114]Signed in"
    else
        echo "#[fg=colour203]Sign-in"
    fi
}

ha() {
    [ -z "$SUPERVISOR_TOKEN" ] && { echo "#[fg=colour245]HA"; return; }
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -m 2 \
        -H "Authorization: Bearer $SUPERVISOR_TOKEN" "http://supervisor/core/api/" 2>/dev/null)
    [ "$code" = "200" ] && echo "#[fg=colour114]HA" || echo "#[fg=colour208]HA"
}

mode() {
    case "${AIDA_MODE:-assisted}" in
        read-only)  echo "#[fg=colour114]read-only" ;;
        autonomous) echo "#[fg=colour214]autonomous" ;;
        *)          echo "#[fg=colour111]assisted" ;;
    esac
}

echo "$(sign_in) #[fg=colour245]| $(ha) #[fg=colour245]| $(mode) #[fg=colour245]| #[fg=colour252]$(date '+%a %H:%M')"
