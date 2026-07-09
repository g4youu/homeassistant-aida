"""Config flow for the Aida conversation-agent integration."""
from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.config_entries import ConfigFlow, ConfigFlowResult

from .const import CONF_HOST, CONF_PORT, CONF_TOKEN, DEFAULT_PORT, DOMAIN


class AidaConfigFlow(ConfigFlow, domain=DOMAIN):
    """Handle a config flow for Aida."""

    VERSION = 1

    async def async_step_user(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        """Ask for the add-on host, port, and bridge token."""
        errors: dict[str, str] = {}

        if user_input is not None:
            return self.async_create_entry(title="Aida", data=user_input)

        schema = vol.Schema(
            {
                vol.Required(CONF_HOST, default="local-aida"): str,
                vol.Required(CONF_PORT, default=DEFAULT_PORT): int,
                vol.Optional(CONF_TOKEN, default=""): str,
            }
        )
        return self.async_show_form(
            step_id="user", data_schema=schema, errors=errors
        )
