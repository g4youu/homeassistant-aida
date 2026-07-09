# Aida — Documentation

## Configuration options

| Option | Default | Description |
|--------|---------|-------------|
| `auth_method` | `oauth` | Sign-in method: `oauth`, `api_key`, `bedrock`, `vertex`. |
| `anthropic_api_key` | `""` | API key (used when `auth_method: api_key`). Stored as a password field. |
| `aws_region` / `aws_access_key_id` / `aws_secret_access_key` / `bedrock_model` | – | Amazon Bedrock credentials (when `auth_method: bedrock`). |
| `gcp_project` / `gcp_region` / `vertex_model` | – | Google Vertex AI settings (when `auth_method: vertex`). |
| `mode` | `assisted` | Safety mode: `read-only`, `assisted`, `autonomous`. |
| `entity_denylist` | `lock`, `alarm_control_panel`, `cover.garage` | Domains/entities Aida may **not** control. |
| `entity_allowlist` | `[]` | Reserved for future scoping to only these entities. |
| `auto_backup` | `true` | Back up files under `/config` before editing. |
| `audit_log` | `true` | Record every tool use to `/config/aida/audit.log`. |
| `auto_launch` | `true` | Start Claude immediately vs. show the session picker. |
| `ha_smart_context` | `true` | Generate a Home Assistant context file on startup. |
| `enable_ha_mcp` | `true` | Register the Home Assistant MCP server for entity control. |
| `enable_bridge` | `true` | Run the conversation bridge (HTTP API on port 7682). |
| `bridge_require_token` | `true` | Require a Bearer token for bridge requests. |
| `persistent_apk_packages` / `persistent_pip_packages` | `[]` | Extra packages reinstalled on every start. |

## How safety is enforced

Two layers work together:

1. **Claude Code policy** (`~/.claude/settings.json`, installed by the add-on):
   auto-allows safe reads, **asks** before writes/service calls, and **denies**
   catastrophic commands and reading secrets.
2. **Runtime hooks** (cannot be bypassed by the model):
   - `guard-hook.sh` (PreToolUse) — blocks catastrophic commands, enforces
     `read-only` mode, and blocks protected entities.
   - `backup-hook.sh` (PreToolUse) — snapshots files before edits.
   - `audit-hook.sh` (PostToolUse) — logs every action.

Backups live in `/config/aida/backups/<timestamp>/…`; restore with a normal
file copy. The audit log is newline-delimited JSON at `/config/aida/audit.log`.

## Conversation bridge API

With `enable_bridge: true`, Aida serves:

- `GET /health` → `{"status":"ok","signed_in":true,"mode":"assisted"}`
- `POST /conversation` with `{"text":"..."}` → `{"response":"..."}`

If `bridge_require_token: true`, send `Authorization: Bearer <token>`. The token
is generated on first start and stored at `/config/aida/bridge-token`.

> Safety note: over the API there is no human to approve actions, so the bridge
> runs Claude in **plan** mode (no writes/state changes) unless the add-on
> `mode` is `autonomous`.

### Wire it into Home Assistant

The add-on is reachable from Home Assistant at `http://<add-on-hostname>:7682`.
The simplest integration is a `rest_command` plus a script. Replace `TOKEN`
with the contents of `/config/aida/bridge-token`, and `ADDON_HOST` with the
add-on's hostname (shown on the add-on's *Info* tab, e.g. `local-aida` or the
`xxxxxxxx-aida` slug host).

```yaml
# configuration.yaml
rest_command:
  aida_ask:
    url: "http://ADDON_HOST:7682/conversation"
    method: POST
    headers:
      Authorization: "Bearer TOKEN"
      Content-Type: "application/json"
    payload: '{"text": "{{ text }}"}'
    timeout: 120

# Example: expose the answer via an input_text + script
script:
  ask_aida:
    sequence:
      - service: rest_command.aida_ask
        data:
          text: "{{ question }}"
        response_variable: aida
      - service: input_text.set_value
        target:
          entity_id: input_text.aida_answer
        data:
          value: "{{ aida['content']['response'][:255] }}"
```

### Use Aida as an Assist conversation agent (advanced)

A minimal custom integration that registers Aida as a conversation agent is
scaffolded under [`integration/custom_components/aida/`](integration/custom_components/aida/).
Copy that folder into your Home Assistant `config/custom_components/`, restart,
add the **Aida** integration, then select *Aida* as the conversation agent for
an Assist pipeline (Settings → Voice assistants). This lets you talk to Aida by
voice or from the Assist chat on any dashboard.

> This custom component talks to the same bridge API. It is provided as a
> starting point and runs in your Home Assistant, not the add-on.

## Terminal commands

| Command | Purpose |
|---------|---------|
| `sign-in` | Choose or switch sign-in method; check status. |
| `aida-context` | Regenerate the Home Assistant context file. |
| `persist-install apk\|pip <pkg>` | Install packages that survive restarts. |
| `session-picker` | Choose how to start a session. |

## Troubleshooting

- **Not signed in**: run `sign-in` in the terminal, or set credentials in the
  Configuration tab and restart.
- **Bridge unreachable from HA**: confirm `enable_bridge: true`, that port 7682
  is shown on the add-on Info tab, and that you used the correct add-on host.
- **An action was blocked**: check `mode` and `entity_denylist`. `read-only`
  blocks all changes; protected entities are blocked in every mode.
