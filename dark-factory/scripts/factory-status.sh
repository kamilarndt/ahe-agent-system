#!/usr/bin/env bash
# Dark Factory — Status: dashboard for all running factories
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Dark Factory Status Dashboard${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

sessions=$(tmux list-sessions 2>/dev/null | grep "dark-factory-" || true)

if [ -z "$sessions" ]; then
  echo -e "${YELLOW}No Dark Factory sessions running.${NC}"
  echo "Start one: ./factory-start.sh <team-type> <project-dir> \"<prompt>\""
  exit 0
fi

echo "$sessions" | while read -r line; do
  session=$(echo "$line" | cut -d: -f1)
  created=$(echo "$line" | cut -d' ' -f3-)

  echo -e "${CYAN}Session:${NC} $session"
  echo -e "  ${CYAN}Created:${NC} $created"

  # Count panes and their status
  pane_count=$(tmux list-panes -t "$session" 2>/dev/null | wc -l)
  pane_info=$(tmux list-panes -t "$session" -F "#{pane_index}|#{pane_title}|#{pane_pid}" 2>/dev/null)

  echo "  Panes: $pane_count"

  echo "$pane_info" | while IFS='|' read -r idx title pid; do
    [ -z "$idx" ] && continue
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      status="${GREEN}active${NC}"
    elif [ -n "$pid" ]; then
      status="${RED}dead${NC}"
    else
      status="${YELLOW}waiting${NC}"
    fi
    echo "    [$((idx+1))] $title  $status"
  done

  # Check log dir
  log_dir="$HOME/.hermes/agents/dark-factory/logs/$session"
  if [ -d "$log_dir" ]; then
    echo "  Logs: $(ls $log_dir/*.log 2>/dev/null | wc -l) files"
  fi

  echo ""
done
