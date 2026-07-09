# Aida for Home Assistant

**Aida** is an agentic, safety-first AI assistant add-on for Home Assistant,
powered by the Claude Code CLI. It can read and edit your configuration,
control entities, write automations, debug logs, and run tasks — with
guardrails on by default.

## Install

1. In Home Assistant go to **Settings → Add-ons → Add-on Store**.
2. Open the **⋮** menu (top-right) → **Repositories**.
3. Add this repository URL:
   ```
   https://github.com/g4youu/homeassistant-aida
   ```
4. Find **Aida** in the store, install it, and open the Web UI.

## What's inside

- **Safety modes**: `read-only`, `assisted` (default), `autonomous`
- **Guardrails**: blocks catastrophic commands and protected entities, backs up
  every `/config` file before edits, and logs every action
- **Easy multi-method sign-in**: Claude account (OAuth), Anthropic API key,
  Amazon Bedrock, or Google Vertex AI
- **Talk to it from Assist**: an optional conversation bridge + custom component
  register Aida as a Home Assistant conversation agent
- **Home Assistant aware**: bundled `ha-mcp` entity control and auto-generated
  context about your specific install

See [`aida/README.md`](aida/README.md) and [`aida/DOCS.md`](aida/DOCS.md) for the
full documentation and configuration reference.

## License

MIT
