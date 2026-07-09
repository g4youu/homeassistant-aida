#!/usr/bin/with-contenv bashio
# Configure Claude Code to use ha-mcp (Home Assistant MCP Server) so Aida can
# control entities, automations, scripts and more via natural language.
# Repository: https://github.com/homeassistant-ai/ha-mcp
#
# NOTE: no `set -e`, and every `claude` call runs with stdin from /dev/null and
# wrapped in `timeout`. The first `claude` invocation can trigger first-run
# onboarding that blocks on stdin; without these guards it hangs startup and the
# web terminal never comes up.

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

    bashio::log.info "Configuring Home Assistant MCP server..."

    # Remove any stale registration (never blocks).
    timeout 20 claude mcp remove home-assistant </dev/null >/dev/null 2>&1 || true

    # Register ha-mcp. `claude mcp add` only writes config; it does not run uvx.
    if timeout 30 claude mcp add home-assistant \
        --env "HOMEASSISTANT_URL=http://supervisor/core" \
        --env "HOMEASSISTANT_TOKEN=${SUPERVISOR_TOKEN}" \
        -- uvx --index-strategy unsafe-best-match ha-mcp@3.5.1 </dev/null; then
        bashio::log.info "ha-mcp configured — Aida can act on Home Assistant."
    else
        bashio::log.warning "ha-mcp registration timed out or failed; continuing without it."
        bashio::log.warning "Set it up later from the terminal with: claude mcp add ..."
    fi
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_ha_mcp_server
fi
