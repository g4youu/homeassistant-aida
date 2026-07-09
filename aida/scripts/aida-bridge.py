#!/usr/bin/env python3
"""Aida conversation bridge.

Exposes a small HTTP API that runs Claude Code headlessly (`claude -p`) so
Home Assistant can talk to Aida from Assist, automations, dashboards or
notifications.

Endpoints
---------
GET  /health         -> {"status": "ok", "signed_in": bool}
POST /conversation   -> {"text": "..."}  =>  {"response": "..."}

Auth
----
When AIDA_BRIDGE_TOKEN is set, requests must send
``Authorization: Bearer <token>``.

Safety
------
There is no human to approve tool use over the API, so the bridge runs Claude
in a constrained permission mode derived from the add-on's safety mode:

    read-only / assisted  -> "plan"        (no writes, no state changes)
    autonomous            -> "acceptEdits" (guard hook still enforces denylists)
"""
import asyncio
import json
import os
from aiohttp import web

TOKEN = os.environ.get("AIDA_BRIDGE_TOKEN", "")
PORT = int(os.environ.get("AIDA_BRIDGE_PORT", "7682"))
MODE = os.environ.get("AIDA_MODE", "assisted")
CONFIG_DIR = os.environ.get("ANTHROPIC_CONFIG_DIR", "")

# Headless permission mode: never allow silent writes unless explicitly autonomous.
PERMISSION_MODE = "acceptEdits" if MODE == "autonomous" else "plan"


def _authorized(request: web.Request) -> bool:
    if not TOKEN:
        return True
    header = request.headers.get("Authorization", "")
    return header == f"Bearer {TOKEN}"


def _signed_in() -> bool:
    if os.environ.get("ANTHROPIC_API_KEY"):
        return True
    if os.environ.get("CLAUDE_CODE_USE_BEDROCK") == "1":
        return True
    if os.environ.get("CLAUDE_CODE_USE_VERTEX") == "1":
        return True
    for name in (".credentials.json", "credentials.json"):
        if CONFIG_DIR and os.path.exists(os.path.join(CONFIG_DIR, name)):
            return True
    return False


async def health(request: web.Request) -> web.Response:
    return web.json_response({"status": "ok", "signed_in": _signed_in(), "mode": MODE})


async def conversation(request: web.Request) -> web.Response:
    if not _authorized(request):
        return web.json_response({"error": "unauthorized"}, status=401)

    try:
        body = await request.json()
    except Exception:
        return web.json_response({"error": "invalid JSON"}, status=400)

    text = (body.get("text") or "").strip()
    if not text:
        return web.json_response({"error": "missing 'text'"}, status=400)

    cmd = [
        "claude", "-p", text,
        "--output-format", "json",
        "--permission-mode", PERMISSION_MODE,
    ]

    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd="/config",
            env=os.environ.copy(),
        )
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=120)
    except asyncio.TimeoutError:
        return web.json_response({"error": "timeout"}, status=504)
    except FileNotFoundError:
        return web.json_response({"error": "claude CLI not found"}, status=500)

    if proc.returncode != 0:
        return web.json_response(
            {"error": "claude failed", "detail": stderr.decode(errors="replace")[:1000]},
            status=500,
        )

    raw = stdout.decode(errors="replace").strip()
    # `--output-format json` returns a result envelope; fall back to raw text.
    answer = raw
    try:
        parsed = json.loads(raw)
        answer = parsed.get("result") or parsed.get("text") or raw
    except (json.JSONDecodeError, AttributeError):
        pass

    return web.json_response({"response": answer, "mode": MODE})


def main() -> None:
    app = web.Application()
    app.router.add_get("/health", health)
    app.router.add_post("/conversation", conversation)
    web.run_app(app, host="0.0.0.0", port=PORT, print=None)


if __name__ == "__main__":
    main()
