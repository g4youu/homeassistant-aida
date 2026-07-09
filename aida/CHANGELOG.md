# Changelog

## 1.0.1

### 🐛 Bug Fixes
- **Fixed the web terminal never starting (502 Bad Gateway / ingress "Cannot
  connect to :7681").** Startup hung at "Configuring Home Assistant MCP
  server..." because the first `claude` invocation blocked on a first-run
  onboarding prompt. All boot-time `claude` calls now run with stdin closed and
  a `timeout`, and every optional step (ha-mcp, bridge, context) is now
  non-fatal — the web terminal always starts even if they fail.
- Removed `set -e` from the orchestrator so a single optional-step failure can
  no longer abort startup.

### 🛠️ Housekeeping
- Dropped the deprecated `armv7` architecture (kept `aarch64`, `amd64`).
- Corrected the repository URL in `config.yaml` and image labels.

> Note: if ha-mcp doesn't register on the first boot after updating, restart the
> add-on once after completing Claude sign-in in the terminal.

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
