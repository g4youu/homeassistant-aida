# Changelog

## 1.0.0

Initial release of **Aida** — an agentic AI assistant for Home Assistant,
powered by Claude Code.

### ✨ Features
- **Agentic assistant**: reads/edits `/config`, controls Home Assistant via the
  bundled `ha-mcp` server, runs tasks and debugging.
- **Safety modes**: `read-only`, `assisted` (default), and `autonomous`.
- **Guard hook**: blocks catastrophic commands and protected entities in every
  mode; blocks all changes in read-only mode.
- **Automatic backups**: every `/config` file is snapshotted before Aida edits it.
- **Audit log**: every action recorded to `/config/aida/audit.log`.
- **Easy multi-method sign-in**: Claude account (OAuth), Anthropic API key,
  Amazon Bedrock, or Google Vertex AI — with a friendly `sign-in` helper.
- **Conversation bridge**: HTTP API (port 7682) to talk to Aida from Home
  Assistant Assist, automations, dashboards and notifications.
- **Assist conversation-agent scaffold**: a copy-in custom component under
  `integration/custom_components/aida/`.
- **HA smart context**: `aida-context` generates a per-install context file.
- **Reliability**: `ttyd` baked into the image; Claude Code CLI version pinnable
  via build arg.
