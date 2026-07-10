# Changelog

## 1.0.6

### 🐛 Bug Fixes
- **Claude Code hung on startup on Alpine/musl.** Diagnostics showed `claude`
  never returning — even `claude --version` — which froze the whole terminal.
  Claude Code is a glibc program; the image now ships `gcompat`, `libstdc++` and
  `libgcc` so the CLI and its bundled native helpers actually run on the
  Alpine/musl add-on base.

### 🩺 Diagnostics
- The startup health probe no longer wedges itself. It previously captured
  `claude --version` with `$(...)`, which blocks forever when Claude leaves a
  background child holding the output pipe — so the report cut off mid-file.
  Probes now write straight to `/config/aida/diagnostics.txt` and hard-kill on
  timeout, so you always get the full arch/libc/version/connectivity/`claude -p`
  report.

## 1.0.5

### 🐛 Bug Fixes
- **Terminal froze after the banner (Claude hung on startup).** In a locked-down
  add-on container, Claude Code's boot-time non-essential network calls
  (auto-updater, telemetry, error reporting) could stall with no output — the
  banner showed and then everything you typed was swallowed. Aida now disables
  those calls (`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`,
  `DISABLE_AUTOUPDATER=1`, …) so Claude goes straight to its login/prompt.

### 🩺 Diagnostics
- On every start Aida now writes a short health probe to the **add-on Log** and
  to **`/config/aida/diagnostics.txt`** (openable in Studio Code Server): arch,
  libc, Node/Claude versions, connectivity to Anthropic, and a headless Claude
  test. It runs in the background and never delays the terminal.

## 1.0.4

### 🐛 Bug Fixes
- **Sign-in now works on installs upgraded from 1.0.1/1.0.2.** Those versions
  persisted `hasCompletedOnboarding: true` into `/data`, which survives updates.
  1.0.3 stopped *setting* that flag but never *cleared* it — so Claude still
  thought it was onboarded, skipped its own login screen, and the terminal
  opened on a dead `sh` shell. Aida now **removes the stale flag whenever no
  credentials are present**, so Claude reliably shows its login screen; when
  you're already signed in it stays pre-completed for a fast, prompt-free start.
  A default theme is also seeded so the theme picker never blocks.
- **No more blank/`sh` terminal if Claude exits.** The terminal now launches via
  a small wrapper (`aida-run`) that drops to a normal shell with guidance
  (“type `claude` to relaunch, or `sign-in` …”) instead of a bare, confusing
  prompt.

> Already upgraded and still stuck at a blank terminal? Run this once in the Aida
> terminal, then complete the login:
> `jq 'del(.hasCompletedOnboarding)' "$HOME/.claude.json" > /tmp/c && mv /tmp/c "$HOME/.claude.json" && claude`

## 1.0.3

### 🐛 Bug Fixes
- **ha-mcp now registers reliably.** It was still timing out because
  `claude mcp add` blocks on Claude Code's first-run prompts. The Home Assistant
  MCP server is now written directly into `~/.claude.json` — instant,
  deterministic, and it can't hang startup.
- **Claude's login screen now appears.** The onboarding seed no longer marks
  onboarding "complete" (which could skip the login prompt); it only accepts the
  `/config` trust dialog, so Claude runs its native first-run and shows its own
  login. Existing installs: type `/login` in the terminal once to sign in.

## 1.0.2

### 🚀 Improvements
- **Terminal now opens in seconds instead of ~50s.** ha-mcp registration was
  waiting on Claude Code's first-run onboarding; it now runs in the background
  and no longer delays the web terminal.
- **Fixed sign-in showing no login link.** Claude Code's first-run onboarding /
  theme picker was blocking before the login prompt appeared. Onboarding + the
  `/config` trust dialog are now pre-completed, so the terminal drops straight
  to Claude's native login screen. The extra `sign-in --ensure` wrapper on
  launch was removed — Claude drives its own login.

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
