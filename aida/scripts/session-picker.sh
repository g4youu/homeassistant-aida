#!/bin/bash
# Aida session picker — choose how to start a session. Uses tmux for
# persistence so navigating away and back reconnects to the same session.

SESSION="aida"
PERM="${AIDA_PERMISSION_MODE:-default}"
TERRACOTTA='\033[38;2;217;119;87m'
NC='\033[0m'

has_session() { tmux has-session -t "$SESSION" 2>/dev/null; }

menu() {
    clear
    echo ""
    echo -e "  ${TERRACOTTA}Aida · Session${NC}"
    echo ""
    has_session && echo "   0) 🔄 Reconnect to running session (recommended)" && echo ""
    echo "   1) 🆕 New session"
    echo "   2) ⏩ Continue last conversation (-c)"
    echo "   3) 📋 Resume from list (-r)"
    echo "   4) 🔐 Sign-in helper"
    echo "   5) 🐚 Bash shell"
    echo ""
    printf "  Choose: "
}

launch() { has_session && tmux kill-session -t "$SESSION" 2>/dev/null; exec tmux new-session -s "$SESSION" "claude --permission-mode ${PERM} $1"; }

while true; do
    menu; read -r c
    case "$c" in
        0) has_session && exec tmux attach-session -t "$SESSION" ;;
        1|"") launch "" ;;
        2) launch "-c" ;;
        3) launch "-r" ;;
        4) exec sign-in ;;
        5) exec bash ;;
        *) echo "Invalid."; sleep 1 ;;
    esac
done
