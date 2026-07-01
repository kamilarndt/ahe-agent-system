#!/usr/bin/env bash
# Dark Factory — Attach to a specific pane (observe only)
# Usage: factory-attach.sh <session> <pane-number>
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <session-name> [pane-number]"
  echo "  If pane-number is omitted, shows all panes."
  exit 1
fi

SESSION="$1"
PANE="${2:-}"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Session not found: $SESSION"
  echo "Running sessions:"
  tmux list-sessions 2>/dev/null | grep "dark-factory-" || echo "(none)"
  exit 1
fi

if [ -n "$PANE" ]; then
  # Attach in read-only mode
  echo "Attaching to $SESSION pane $PANE (Ctrl+B D to detach)..."
  sleep 1
  tmux attach-session -t "$SESSION:0.$PANE"
else
  echo "Available panes in $SESSION:"
  tmux list-panes -t "$SESSION" -F "  [#{pane_index}] #{pane_title} (PID: #{pane_pid})"
  echo ""
  echo "Run: $0 $SESSION <pane-number>"
fi
