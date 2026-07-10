#!/usr/bin/with-contenv bashio

# Aida — agentic AI assistant for Home Assistant
# Orchestrates sign-in, safety policy, context, MCP, conversation bridge,
# and the web terminal.
#
# NOTE: intentionally NO `set -e`. This is an orchestrator that calls several
# optional/external steps (ha-mcp, bridge, context). None of them may prevent
# the web terminal from starting, so failures are handled locally instead of
# aborting the whole script.

AIDA_HOME="/opt/aida"
AIDA_SCRIPTS="${AIDA_HOME}/scripts"
AIDA_STATE="/config/aida"

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
init_environment() {
    local data_home="/data/home"
    local config_dir="/data/.config"
    local cache_dir="/data/.cache"
    local state_dir="/data/.local/state"
    local claude_config_dir="/data/.config/claude"

    bashio::log.info "Initializing Aida environment..."

    mkdir -p "$data_home" "$config_dir/claude" "$cache_dir" "$state_dir" \
             "/data/.local/share" "${AIDA_STATE}/backups"

    export HOME="$data_home"
    export XDG_CONFIG_HOME="$config_dir"
    export XDG_CACHE_HOME="$cache_dir"
    export XDG_STATE_HOME="$state_dir"
    export XDG_DATA_HOME="/data/.local/share"
    export ANTHROPIC_CONFIG_DIR="$claude_config_dir"

    # Stop Claude Code's boot-time non-essential network calls (auto-updater,
    # telemetry, error reporting). In a locked-down add-on container these can
    # hang with no output — the terminal shows the banner and then freezes.
    # Disabling them lets Claude go straight to its login/prompt.
    export DISABLE_AUTOUPDATER=1
    export DISABLE_TELEMETRY=1
    export DISABLE_ERROR_REPORTING=1
    export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

    # Make Aida scripts callable by short name from the terminal
    export PATH="${AIDA_SCRIPTS}:${PATH}"

    # tmux config
    if [ -f "${AIDA_SCRIPTS}/tmux.conf" ]; then
        cp "${AIDA_SCRIPTS}/tmux.conf" "$data_home/.tmux.conf"
    fi

    # Seed Claude Code's first-run state so the terminal is friction-free:
    #   * accept the /config trust dialog (no prompt),
    #   * pick a default theme (no theme picker),
    #   * decide onboarding based on whether we're actually signed in.
    #
    # If OAuth credentials already exist, mark onboarding complete so Claude drops
    # straight into its prompt. If NOT signed in, actively DELETE any leftover
    # `hasCompletedOnboarding` flag (Aida 1.0.2 persisted it into /data, which
    # survives updates) so Claude runs its native first-run and shows the login
    # screen. Without this, an install that was signed out kept skipping login and
    # opened on a dead shell. Merge into any existing config so credentials and
    # MCP registrations are preserved.
    local claude_json="$data_home/.claude.json"
    local signed_in="false"
    if [ -f "$claude_config_dir/.credentials.json" ] || [ -f "$claude_config_dir/credentials.json" ]; then
        signed_in="true"
    fi
    local merged
    merged=$(jq -n --argjson signedin "$signed_in" \
        --slurpfile existing <(cat "$claude_json" 2>/dev/null || echo '{}') '
        ($existing[0] // {}) as $e |
        $e
        | .theme = ($e.theme // "dark")
        | (if $signedin then .hasCompletedOnboarding = true else del(.hasCompletedOnboarding) end)
        | .projects = (($e.projects // {}) * {"/config": (($e.projects["/config"] // {}) + {hasTrustDialogAccepted: true, projectOnboardingSeenCount: 1})})
    ' 2>/dev/null)
    if [ -n "$merged" ]; then
        printf '%s\n' "$merged" > "$claude_json"
        if [ "$signed_in" = "true" ]; then
            bashio::log.info "Claude Code already signed in — onboarding pre-completed."
        else
            bashio::log.info "Not signed in — Claude will show its login screen on launch."
        fi
    fi

    bashio::log.info "  HOME=$HOME"
    bashio::log.info "  Claude config=$ANTHROPIC_CONFIG_DIR"
}

# ---------------------------------------------------------------------------
# Safety policy (mode + Claude Code settings.json with hooks)
# ---------------------------------------------------------------------------
setup_safety_policy() {
    local mode
    mode=$(bashio::config 'mode' 'assisted')
    export AIDA_MODE="$mode"
    export AIDA_AUTO_BACKUP
    export AIDA_AUDIT_LOG
    export AIDA_ENTITY_DENYLIST
    export AIDA_ENTITY_ALLOWLIST
    AIDA_AUTO_BACKUP=$(bashio::config 'auto_backup' 'true')
    AIDA_AUDIT_LOG=$(bashio::config 'audit_log' 'true')
    AIDA_ENTITY_DENYLIST=$(bashio::config 'entity_denylist' | jq -r '. // [] | join(",")' 2>/dev/null || echo "")
    AIDA_ENTITY_ALLOWLIST=$(bashio::config 'entity_allowlist' | jq -r '. // [] | join(",")' 2>/dev/null || echo "")

    bashio::log.info "Safety mode: ${mode}"

    # Install the managed Claude Code settings (permissions + hooks) into HOME.
    local claude_dir="${HOME}/.claude"
    mkdir -p "$claude_dir"
    if [ -f "${AIDA_HOME}/claude/settings.json" ]; then
        cp "${AIDA_HOME}/claude/settings.json" "$claude_dir/settings.json"
        bashio::log.info "Installed Claude Code safety policy -> $claude_dir/settings.json"
    fi

    # Map mode -> Claude Code default permission mode
    case "$mode" in
        read-only)   export AIDA_PERMISSION_MODE="plan" ;;
        assisted)    export AIDA_PERMISSION_MODE="default" ;;
        autonomous)  export AIDA_PERMISSION_MODE="acceptEdits" ;;
        *)           export AIDA_PERMISSION_MODE="default" ;;
    esac
}

# ---------------------------------------------------------------------------
# Sign-in (multiple methods, easy setup)
# ---------------------------------------------------------------------------
setup_authentication() {
    local method
    method=$(bashio::config 'auth_method' 'oauth')
    export AIDA_AUTH_METHOD="$method"

    bashio::log.info "Sign-in method: ${method}"

    case "$method" in
        api_key)
            local key=""
            if bashio::config.has_value 'anthropic_api_key'; then
                key=$(bashio::config 'anthropic_api_key')
            fi
            # Fallback: key file in /config for users who prefer a file
            if [ -z "$key" ] && [ -f "${AIDA_STATE}/anthropic_api_key" ]; then
                key=$(tr -d '[:space:]' < "${AIDA_STATE}/anthropic_api_key")
            fi
            if [ -n "$key" ]; then
                export ANTHROPIC_API_KEY="$key"
                bashio::log.info "API key sign-in configured."
            else
                bashio::log.warning "auth_method=api_key but no key set. Run 'sign-in' in the terminal."
            fi
            ;;
        bedrock)
            export CLAUDE_CODE_USE_BEDROCK=1
            bashio::config.has_value 'aws_region'            && export AWS_REGION="$(bashio::config 'aws_region')"
            bashio::config.has_value 'aws_access_key_id'     && export AWS_ACCESS_KEY_ID="$(bashio::config 'aws_access_key_id')"
            bashio::config.has_value 'aws_secret_access_key' && export AWS_SECRET_ACCESS_KEY="$(bashio::config 'aws_secret_access_key')"
            bashio::config.has_value 'bedrock_model'         && export ANTHROPIC_MODEL="$(bashio::config 'bedrock_model')"
            bashio::log.info "Amazon Bedrock sign-in configured."
            ;;
        vertex)
            export CLAUDE_CODE_USE_VERTEX=1
            bashio::config.has_value 'gcp_project' && export ANTHROPIC_VERTEX_PROJECT_ID="$(bashio::config 'gcp_project')"
            bashio::config.has_value 'gcp_region'  && export CLOUD_ML_REGION="$(bashio::config 'gcp_region')"
            bashio::config.has_value 'vertex_model' && export ANTHROPIC_MODEL="$(bashio::config 'vertex_model')"
            if [ -f "${AIDA_STATE}/vertex-credentials.json" ]; then
                export GOOGLE_APPLICATION_CREDENTIALS="${AIDA_STATE}/vertex-credentials.json"
            fi
            bashio::log.info "Google Vertex AI sign-in configured."
            ;;
        oauth|*)
            # Interactive OAuth (Claude Pro/Max or Console login). Credentials
            # persist in $ANTHROPIC_CONFIG_DIR under /data. If not yet signed in,
            # the terminal's first run guides the user via 'sign-in'.
            bashio::log.info "OAuth sign-in — log in on first terminal launch (or run 'sign-in')."
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Persistent packages
# ---------------------------------------------------------------------------
install_persistent_packages() {
    local apk_packages pip_packages persist="/data/persistent-packages.json"
    apk_packages=$(bashio::config 'persistent_apk_packages' | jq -r '. // [] | join(" ")' 2>/dev/null || echo "")
    pip_packages=$(bashio::config 'persistent_pip_packages' | jq -r '. // [] | join(" ")' 2>/dev/null || echo "")

    # Merge packages saved at runtime via `persist-install`
    if [ -f "$persist" ]; then
        apk_packages="$apk_packages $(jq -r '.apk_packages | join(" ")' "$persist" 2>/dev/null)"
        pip_packages="$pip_packages $(jq -r '.pip_packages | join(" ")' "$persist" 2>/dev/null)"
    fi
    apk_packages=$(echo "$apk_packages" | xargs)
    pip_packages=$(echo "$pip_packages" | xargs)

    if [ -n "$apk_packages" ]; then
        bashio::log.info "Installing APK packages: $apk_packages"
        # shellcheck disable=SC2086
        apk add --no-cache $apk_packages || bashio::log.warning "Some APK packages failed"
    fi
    if [ -n "$pip_packages" ]; then
        bashio::log.info "Installing pip packages: $pip_packages"
        # shellcheck disable=SC2086
        pip3 install --break-system-packages --no-cache-dir $pip_packages || bashio::log.warning "Some pip packages failed"
    fi
}

# ---------------------------------------------------------------------------
# HA smart context (CLAUDE.md)
# ---------------------------------------------------------------------------
generate_ha_context() {
    if [ "$(bashio::config 'ha_smart_context' 'true')" != "true" ]; then
        bashio::log.info "HA smart context disabled."
        return
    fi
    if [ -f "${AIDA_SCRIPTS}/aida-context.sh" ]; then
        bashio::log.info "Generating Home Assistant context..."
        "${AIDA_SCRIPTS}/aida-context.sh" >/dev/null 2>&1 || bashio::log.warning "Context generation had issues"
    fi
}

# ---------------------------------------------------------------------------
# ha-mcp integration
# ---------------------------------------------------------------------------
setup_ha_mcp() {
    if [ "$(bashio::config 'enable_ha_mcp' 'true')" != "true" ]; then
        bashio::log.info "ha-mcp integration disabled."
        return
    fi
    if [ -f "${AIDA_SCRIPTS}/setup-ha-mcp.sh" ]; then
        # shellcheck source=/dev/null
        source "${AIDA_SCRIPTS}/setup-ha-mcp.sh"
        configure_ha_mcp_server || bashio::log.warning "ha-mcp setup had issues"
    fi
}

# ---------------------------------------------------------------------------
# Conversation bridge (headless claude -p over HTTP for HA Assist)
# ---------------------------------------------------------------------------
start_bridge() {
    if [ "$(bashio::config 'enable_bridge' 'true')" != "true" ]; then
        bashio::log.info "Conversation bridge disabled."
        return
    fi
    if [ ! -f "${AIDA_SCRIPTS}/aida-bridge.py" ]; then
        bashio::log.warning "Bridge script missing, skipping."
        return
    fi

    # Generate / load a bridge token so only authorized callers can use the API.
    if [ "$(bashio::config 'bridge_require_token' 'true')" = "true" ]; then
        if [ ! -f "${AIDA_STATE}/bridge-token" ]; then
            head -c 24 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' > "${AIDA_STATE}/bridge-token"
        fi
        AIDA_BRIDGE_TOKEN=$(cat "${AIDA_STATE}/bridge-token")
        export AIDA_BRIDGE_TOKEN
        bashio::log.info "Bridge token: ${AIDA_STATE}/bridge-token (use as Bearer token)"
    fi

    export AIDA_BRIDGE_PORT="7682"
    bashio::log.info "Starting conversation bridge on :7682 ..."
    python3 "${AIDA_SCRIPTS}/aida-bridge.py" &
}

# ---------------------------------------------------------------------------
# Web terminal
# ---------------------------------------------------------------------------
install_helpers() {
    for s in sign-in aida-context welcome persist-install session-picker aida-run; do
        if [ -f "${AIDA_SCRIPTS}/${s}.sh" ]; then
            cp "${AIDA_SCRIPTS}/${s}.sh" "/usr/local/bin/${s}"
            chmod +x "/usr/local/bin/${s}"
        fi
    done
    bashio::addon.version > "${AIDA_HOME}/addon-version" 2>/dev/null || echo "unknown" > "${AIDA_HOME}/addon-version"
}

get_launch_command() {
    # Auto-launch drops into Claude via a small wrapper (aida-run) that shows the
    # banner, launches Claude, and — if Claude ever exits — leaves a usable shell
    # with guidance instead of a blank prompt. The wrapper runs *inside* tmux so
    # the banner is visible in the pane and the session survives reconnects.
    if [ "$(bashio::config 'auto_launch' 'true')" = "true" ]; then
        echo "tmux new-session -A -s aida aida-run"
    else
        local prefix=""
        [ -f /usr/local/bin/welcome ] && prefix="welcome; "
        echo "${prefix}session-picker"
    fi
}

start_web_terminal() {
    local port=7681
    bashio::log.info "Starting web terminal on :${port} ..."
    export TTYD=1

    local launch_command
    launch_command=$(get_launch_command)

    local theme='{"background":"#16161e","foreground":"#c0caf5","cursor":"#7aa2f7","selectionBackground":"#33467c","black":"#15161e","red":"#f7768e","green":"#9ece6a","yellow":"#e0af68","blue":"#7aa2f7","magenta":"#bb9af7","cyan":"#7dcfff","white":"#a9b1d6","brightBlack":"#414868","brightRed":"#f7768e","brightGreen":"#9ece6a","brightYellow":"#e0af68","brightBlue":"#7aa2f7","brightMagenta":"#bb9af7","brightCyan":"#7dcfff","brightWhite":"#c0caf5"}'

    exec ttyd \
        --port "${port}" \
        --interface 0.0.0.0 \
        --writable \
        --ping-interval 30 \
        --client-option enableReconnect=true \
        --client-option reconnect=10 \
        --client-option "theme=${theme}" \
        --client-option fontSize=14 \
        bash -c "$launch_command"
}

# ---------------------------------------------------------------------------
# Startup diagnostics
# ---------------------------------------------------------------------------
# Runs in the background so it never delays the terminal. Writes to the add-on
# Log AND to /config/aida/diagnostics.txt (openable in Studio Code Server), so
# we can see why Claude misbehaves even when the interactive terminal is stuck.
run_diagnostics() {
    local out="${AIDA_STATE}/diagnostics.txt"
    {
        echo "=== Aida diagnostics $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
        echo "addon-version : $(cat "${AIDA_HOME}/addon-version" 2>/dev/null || echo '?')"
        echo "arch          : $(uname -m)"
        echo "libc          : $(ls /lib/ld-musl-* >/dev/null 2>&1 && echo musl || echo glibc)"
        echo "node          : $(node --version 2>&1)"
        echo "which claude  : $(command -v claude 2>&1)"
        local v rc
        v=$(timeout 15 claude --version 2>&1); rc=$?
        echo "claude --version : rc=${rc} :: ${v}"
        local http
        http=$(curl -sS -m 12 -o /dev/null -w '%{http_code}' https://api.anthropic.com/ 2>&1); rc=$?
        echo "api.anthropic.com     : http=${http} curl_rc=${rc}"
        http=$(curl -sS -m 12 -o /dev/null -w '%{http_code}' https://console.anthropic.com/ 2>&1); rc=$?
        echo "console.anthropic.com : http=${http} curl_rc=${rc}"
        local pout prc
        pout=$(printf '' | timeout 30 claude -p 'reply with the word OK' 2>&1 | head -c 400); prc=$?
        echo "claude -p test : rc=${prc} :: ${pout}"
        echo "=== end diagnostics ==="
    } > "$out" 2>&1

    # Mirror to the add-on Log so it's visible without any file access.
    bashio::log.info "----- Aida startup diagnostics -----"
    while IFS= read -r line; do bashio::log.info "diag| ${line}"; done < "$out"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    bashio::log.info "=== Aida starting ==="
    init_environment       || bashio::log.warning "init_environment reported an issue"
    setup_safety_policy    || bashio::log.warning "setup_safety_policy reported an issue"
    setup_authentication   || bashio::log.warning "setup_authentication reported an issue"
    install_helpers        || bashio::log.warning "install_helpers reported an issue"

    # Optional steps — must never block or abort the web terminal.
    install_persistent_packages || bashio::log.warning "persistent packages step skipped"
    generate_ha_context         || bashio::log.warning "context generation skipped"

    # ha-mcp is now a direct JSON write (instant, no subprocess), so it's safe
    # to run inline before the terminal.
    setup_ha_mcp                || bashio::log.warning "ha-mcp setup skipped"
    start_bridge                || bashio::log.warning "bridge start skipped"

    # Background health probe — logs why Claude misbehaves without delaying start.
    run_diagnostics &

    # Always start the terminal last.
    start_web_terminal
}

main "$@"
