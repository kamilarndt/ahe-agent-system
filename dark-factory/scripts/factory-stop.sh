#!/usr/bin/env bash
# Dark Factory — Stop: gracefully shutdown a factory session
# Usage: factory-stop.sh <session-name>
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -lt 1 ]; then
  echo "Usage: $0 <session-name>"
  echo "Use: factory-status.sh to list running sessions."
  exit 1
fi

SESSION="$1"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo -e "${RED}Session not found: $SESSION${NC}"
  exit 1
fi

echo -e "${YELLOW}Gracefully stopping $SESSION...${NC}"

# Send graceful exit to all panes
pane_count=$(tmux list-panes -t "$SESSION" | wc -l)
for i in $(seq 0 $((pane_count - 1))); do
  tmux send-keys -t "$SESSION:0.$i" '/exit' Enter 2>/dev/null || true
done

sleep 2

# Kill the session
tmux kill-session -t "$SESSION" 2>/dev/null || true
echo -e "${GREEN}Factory stopped: $SESSION${NC}"

# Archive logs
LOG_DIR="$HOME/.hermes/agents/dark-factory/logs/$SESSION"
if [ -d "$LOG_DIR" ]; then
  ARCHIVE="$HOME/.hermes/agents/dark-factory/logs/${SESSION}-$(date +%Y%m%d-%H%M%S).tar.gz"
  tar czf "$ARCHIVE" -C "$HOME/.hermes/agents/dark-factory/logs" "$SESSION" 2>/dev/null || true
  echo "Logs archived: $ARCHIVE"
fi
