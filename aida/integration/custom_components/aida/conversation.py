"""Conversation agent that forwards prompts to the Aida add-on bridge."""
from __future__ import annotations

from homeassistant.components import conversation
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers import intent
from homeassistant.helpers.aiohttp_client import async_get_clientsession
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from .const import CONF_HOST, CONF_PORT, CONF_TOKEN, DEFAULT_PORT


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up the Aida conversation entity."""
    async_add_entities([AidaConversationEntity(entry)])


class AidaConversationEntity(conversation.ConversationEntity):
    """Route Assist conversations to Aida's bridge API."""

    _attr_has_entity_name = True
    _attr_name = "Aida"

    def __init__(self, entry: ConfigEntry) -> None:
        self._entry = entry
        self._attr_unique_id = entry.entry_id
        host = entry.data[CONF_HOST]
        port = entry.data.get(CONF_PORT, DEFAULT_PORT)
        self._url = f"http://{host}:{port}/conversation"
        self._token = entry.data.get(CONF_TOKEN) or ""

    @property
    def supported_languages(self) -> list[str] | str:
        return "*"

    async def async_process(
        self, user_input: conversation.ConversationInput
    ) -> conversation.ConversationResult:
        """Send the user's text to Aida and return the reply."""
        session = async_get_clientsession(self.hass)
        headers = {"Content-Type": "application/json"}
        if self._token:
            headers["Authorization"] = f"Bearer {self._token}"

        response = intent.IntentResponse(language=user_input.language)
        try:
            async with session.post(
                self._url,
                json={"text": user_input.text},
                headers=headers,
                timeout=125,
            ) as resp:
                if resp.status != 200:
                    raise RuntimeError(f"bridge returned {resp.status}")
                data = await resp.json()
                answer = data.get("response", "").strip() or "(no response)"
        except Exception as err:  # noqa: BLE001 - surface any failure to the user
            response.async_set_error(
                intent.IntentResponseErrorCode.UNKNOWN,
                f"Aida is unavailable: {err}",
            )
            return conversation.ConversationResult(
                response=response, conversation_id=user_input.conversation_id
            )

        response.async_set_speech(answer)
        return conversation.ConversationResult(
            response=response, conversation_id=user_input.conversation_id
        )
