# Aida — AI assistant for Home Assistant

Aida is an **agentic** AI assistant for Home Assistant, powered by the Claude
Code CLI. It doesn't just answer questions — it can read and edit your
configuration, control entities, write automations, debug logs, and run
tasks, with **safety guardrails on by default**.

> Sibling add-on to *Claude Terminal* in this repository. Aida adds a safety
> policy engine, multiple easy sign-in methods, and a conversation bridge so
> you can talk to it from Home Assistant Assist — not just the terminal.

## Highlights

- 🧠 **Agentic** — edits `/config`, controls HA via the bundled Home Assistant
  MCP server, runs commands.
- 🛡️ **Safe by default** — three modes (`read-only`, `assisted`, `autonomous`),
  a guard hook that blocks catastrophic and protected-entity actions, automatic
  backups before every file edit, and a full audit log.
- 🔑 **Easy multi-method sign-in** — Claude account (OAuth), Anthropic API key,
  Amazon Bedrock, or Google Vertex AI. A friendly `sign-in` helper walks you
  through it.
- 💬 **Talk to it from Home Assistant** — an optional conversation bridge lets
  you wire Aida into Assist, automations, dashboards and notifications.
- 🏡 **Knows your setup** — generates a context file (`aida-context`) with your
  entities, add-ons, and recent errors so answers are specific to your home.

## Safety modes

| Mode | Behaviour |
|------|-----------|
| `read-only` | Reads and explains only. All edits and state changes are blocked. |
| `assisted` *(default)* | Proposes changes and asks before acting. |
| `autonomous` | Acts without asking — the guard hook still blocks catastrophic actions and protected entities. |

Regardless of mode:
- **Backups**: every file under `/config` is copied to `/config/aida/backups/`
  before Aida edits it.
- **Audit log**: every tool Aida uses is recorded in `/config/aida/audit.log`.
- **Protected entities**: domains/entities in `entity_denylist` (default:
  `lock`, `alarm_control_panel`, `cover.garage`) can't be controlled by Aida.

## Sign-in

Pick a method in the add-on **Configuration** tab (`auth_method`), or just start
the terminal and run `sign-in`:

- **oauth** — log in with your Claude Pro/Max or Console account (no key to
  manage). Credentials persist across restarts.
- **api_key** — paste an Anthropic API key into the config, or run `sign-in`
  and paste it once (saved to `/config/aida/anthropic_api_key`).
- **bedrock** — set `auth_method: bedrock` plus your AWS keys/region.
- **vertex** — set `auth_method: vertex` plus your GCP project/region.

## Talking to Aida from Home Assistant

Enable the bridge (`enable_bridge: true`, on by default). It serves an HTTP API
on port `7682`. See [DOCS.md](DOCS.md) for ready-to-paste `rest_command`,
script, and conversation-agent integration snippets.

## Configuration reference

See [DOCS.md](DOCS.md) for the full option list and integration guide.
