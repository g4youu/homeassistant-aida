#!/bin/bash
# Aida terminal entrypoint — runs inside the tmux session.
#
# Shows the welcome banner, launches Claude Code, and — critically — if Claude
# ever exits, drops to a real interactive shell with guidance instead of a bare,
# confusing `sh` prompt. Reliable sign-in is handled upstream: run.sh removes any
# stale `hasCompletedOnboarding` flag when signed out, so `claude` shows its
# native login screen on first launch.

command -v welcome >/dev/null 2>&1 && welcome

claude --permission-mode "${AIDA_PERMISSION_MODE:-default}"
status=$?

echo
if [ "$status" -ne 0 ]; then
    echo "  Claude exited (code ${status})."
else
    echo "  Claude session ended."
fi
echo "  Type 'claude' to relaunch, or 'sign-in' to switch or repeat sign-in."
echo

# Keep the pane alive with a normal, usable shell (never a blank prompt).
exec bash
