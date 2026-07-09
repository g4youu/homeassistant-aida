#!/bin/bash
# Aida welcome banner (shown inside the terminal). Plain bash, no bashio.

TERRACOTTA='\033[38;2;217;119;87m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

version="unknown"
[ -f /opt/aida/addon-version ] && version=$(cat /opt/aida/addon-version)
mode="${AIDA_MODE:-assisted}"
method="${AIDA_AUTH_METHOD:-oauth}"

case "$mode" in
    read-only)  mode_color="$GREEN";   mode_note="reads only, no changes" ;;
    assisted)   mode_color="$BLUE";    mode_note="asks before changes" ;;
    autonomous) mode_color="$YELLOW";  mode_note="acts without asking (guard still on)" ;;
esac

echo ""
echo -e "  ${TERRACOTTA}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "  ${TERRACOTTA}║${NC}   ${WHITE}Aida${NC}  ${DIM}v${version}${NC}  ·  AI assistant for Home Assistant       ${TERRACOTTA}║${NC}"
echo -e "  ${TERRACOTTA}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "   Mode:     ${mode_color}${mode}${NC} ${DIM}(${mode_note})${NC}"
echo -e "   Sign-in:  ${method}"
echo ""
echo -e "   ${DIM}Commands:${NC}  sign-in   ${DIM}·${NC}  aida-context   ${DIM}·${NC}  persist-install   ${DIM}·${NC}  session-picker"
echo -e "   ${DIM}Backups:${NC}   /config/aida/backups      ${DIM}Audit:${NC}  /config/aida/audit.log"
echo ""
