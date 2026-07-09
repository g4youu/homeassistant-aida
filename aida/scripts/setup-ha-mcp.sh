#!/usr/bin/with-contenv bashio
# Configure Claude Code to use ha-mcp (Home Assistant MCP Server) so Aida can
# control entities, automations, scripts and more via natural language.
# Repository: https://github.com/homeassistant-ai/ha-mcp

set -e

configure_ha_mcp_server() {
    if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
        bashio::log.warning "SUPERVISOR_TOKEN unavailable — skipping ha-mcp."
        return 0
    fi
    if ! command -v uvx >/dev/null 2>&1; then
        bashio::log.warning "uvx not found — skipping ha-mcp."
        return 0
    fi

    bashio::log.info "Configuring Home Assistant MCP server..."
    claude mcp remove home-assistant 2>/dev/null || true

    if claude mcp add home-assistant \
        --env "HOMEASSISTANT_URL=http://supervisor/core" \
        --env "HOMEASSISTANT_TOKEN=${SUPERVISOR_TOKEN}" \
        -- uvx --index-strategy unsafe-best-match ha-mcp@3.5.1; then
        bashio::log.info "ha-mcp configured — Aida can now act on Home Assistant."
    else
        bashio::log.warning "ha-mcp configuration failed — continuing without it."
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_ha_mcp_server
fi
