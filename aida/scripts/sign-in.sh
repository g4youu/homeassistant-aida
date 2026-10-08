#!/bin/bash
# Aida sign-in helper — makes authenticating easy, with several methods.
#
#   sign-in            Interactive menu (choose / switch method, check status)
#   sign-in --ensure   Non-interactive: succeed if already signed in, else
#                      launch the right flow for the configured method
#   sign-in --status   Print current sign-in status and exit
#
# Supported methods: OAuth (Claude Pro/Max or Console), API key,
# Amazon Bedrock, Google Vertex AI.

STATE_DIR="/config/aida"
KEY_FILE="${STATE_DIR}/anthropic_api_key"

TERRACOTTA='\033[38;2;217;119;87m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

TOKEN_FILE="${STATE_DIR}/oauth-token"

is_signed_in() {
    # API-key / Bedrock / Vertex / long-lived token are env-configured — presence == signed in.
    [ -n "$ANTHROPIC_API_KEY" ] && return 0
    [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ] && return 0
    [ -f "$TOKEN_FILE" ] && return 0
    [ "$CLAUDE_CODE_USE_BEDROCK" = "1" ] && return 0
    [ "$CLAUDE_CODE_USE_VERTEX" = "1" ] && return 0
    # OAuth: look for stored credentials.
    local cfg="${ANTHROPIC_CONFIG_DIR:-$HOME/.config/claude}"
    [ -f "${cfg}/.credentials.json" ] && return 0
    [ -f "${cfg}/credentials.json" ] && return 0
    if [ -f "${cfg}/settings.json" ] && grep -q '"oauthToken"\|"sessionKey"\|"apiKey"' "${cfg}/settings.json" 2>/dev/null; then
        return 0
    fi
    return 1
}

print_status() {
    echo ""
    if is_signed_in; then
        echo -e "  ${GREEN}●${NC} Signed in  ${DIM}(method: ${AIDA_AUTH_METHOD:-oauth})${NC}"
    else
        echo -e "  ${YELLOW}●${NC} Not signed in  ${DIM}(configured method: ${AIDA_AUTH_METHOD:-oauth})${NC}"
    fi
    echo ""
}

save_api_key() {
    local key="$1"
    mkdir -p "$STATE_DIR"
    printf '%s' "$key" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    export ANTHROPIC_API_KEY="$key"
}

flow_oauth() {
    echo -e "  ${BOLD}Signing in with your Claude account${NC}"
    echo -e "  ${DIM}A login link/code will appear. Open it in your browser,${NC}"
    echo -e "  ${DIM}approve, and paste the code back here.${NC}"
    echo ""
    echo -e "  ${DIM}Paste tips: Ctrl+Shift+V, right-click, or long-press on mobile.${NC}"
    echo ""
    sleep 1
    claude   # Claude Code drives its own OAuth login on first run
}

flow_api_key() {
    echo -e "  ${BOLD}Sign in with an Anthropic API key${NC}"
    echo -e "  ${DIM}Get one at https://console.anthropic.com/settings/keys${NC}"
    echo ""
    echo -e "  ${DIM}Tip: you can also paste it into the add-on's configuration${NC}"
    echo -e "  ${DIM}(Anthropic API Key field) so it loads automatically.${NC}"
    echo ""
    printf "  Paste API key (sk-ant-...): "
    read -rs key
    echo ""
    if [ -z "$key" ]; then
        echo -e "  ${YELLOW}No key entered.${NC}"
        return 1
    fi
    save_api_key "$key"
    echo -e "  ${GREEN}✔ Saved.${NC} It will be reused automatically next time."
}

save_token() {
    local tok="$1"
    mkdir -p "$STATE_DIR"
    printf '%s' "$tok" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    export CLAUDE_CODE_OAUTH_TOKEN="$tok"
}

flow_token() {
    echo -e "  ${BOLD}Stay signed in with a long-lived token${NC}"
    echo -e "  ${DIM}Generates a token tied to your Claude subscription so Aida doesn't${NC}"
    echo -e "  ${DIM}get logged out every few days — still your Pro/Max plan, no API billing.${NC}"
    echo ""
    echo -e "  ${DIM}A link appears: open it, approve, paste the code back — then copy the${NC}"
    echo -e "  ${DIM}token it prints. Keep that token secret (treat it like a password).${NC}"
    echo ""
    read -rp "  Press Enter to run 'claude setup-token'... " _
    claude setup-token
    echo ""
    echo -e "  ${BOLD}Paste the token shown above to save it here${NC} ${DIM}(or leave blank and${NC}"
    echo -e "  ${DIM}paste it into the add-on's 'Long-lived OAuth token' config field instead):${NC}"
    printf "  Token: "
    read -rs tok
    echo ""
    if [ -z "$tok" ]; then
        echo -e "  ${YELLOW}Nothing saved.${NC} Set it in the add-on config, then restart."
        return 1
    fi
    save_token "$tok"
    echo -e "  ${GREEN}✔ Saved${NC} to ${TOKEN_FILE} (chmod 600). Restart the add-on to apply."
}

show_menu() {
    clear
    echo ""
    echo -e "  ${TERRACOTTA}╔══════════════════════════════════════════════╗${NC}"
    echo -e "  ${TERRACOTTA}║${NC}   ${BOLD}Aida${NC} · Sign-in                             ${TERRACOTTA}║${NC}"
    echo -e "  ${TERRACOTTA}╚══════════════════════════════════════════════╝${NC}"
    print_status
    echo "  How would you like to sign in?"
    echo ""
    echo "   1) 🟣 Claude account (Pro/Max or Console OAuth)"
    echo "   2) 🟢 Stay signed in — long-lived token (recommended for Pro/Max)"
    echo "   3) 🔑 Anthropic API key"
    echo "   4) ☁️  Amazon Bedrock        (set keys in add-on config)"
    echo "   5) ☁️  Google Vertex AI      (set project in add-on config)"
    echo "   6) ℹ️  Show status"
    echo "   7) ➡️  Continue without changing"
    echo ""
    printf "  Choose [1-7]: "
}

interactive() {
    while true; do
        show_menu
        read -r choice
        case "$choice" in
            1) flow_oauth; return 0 ;;
            2) flow_token && return 0 ;;
            3) flow_api_key && return 0 ;;
            4) echo -e "\n  Set ${BOLD}auth_method: bedrock${NC} plus AWS keys in the add-on"
               echo -e "  configuration, then restart the add-on.\n"; read -rp "  Press Enter..." _ ;;
            5) echo -e "\n  Set ${BOLD}auth_method: vertex${NC} plus your GCP project in the add-on"
               echo -e "  configuration, then restart the add-on.\n"; read -rp "  Press Enter..." _ ;;
            6) print_status; read -rp "  Press Enter..." _ ;;
            7) return 0 ;;
            *) echo "  Invalid choice."; sleep 1 ;;
        esac
    done
}

# Non-interactive: used by the terminal launcher before starting Claude.
ensure() {
    if is_signed_in; then
        exit 0
    fi
    case "${AIDA_AUTH_METHOD:-oauth}" in
        api_key)
            echo -e "  ${YELLOW}No API key found.${NC}"
            flow_api_key || true
            ;;
        bedrock|vertex)
            echo -e "  ${YELLOW}Cloud provider sign-in is incomplete.${NC}"
            echo -e "  ${DIM}Check your credentials in the add-on configuration and restart.${NC}"
            sleep 2
            ;;
        oauth|*)
            flow_oauth
            ;;
    esac
    exit 0
}

case "${1:-}" in
    --ensure) ensure ;;
    --status) print_status; exit 0 ;;
    *)        interactive ;;
esac
