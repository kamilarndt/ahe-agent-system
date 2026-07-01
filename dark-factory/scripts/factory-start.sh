#!/usr/bin/env bash
# =============================================================================
# AHE Dark Factory — Enhanced Runtime Automation Layer
# Launches multi-agent tmux sessions with JSONL telemetry buffers,
# exit-state tracking, and structured XML output capture.
#
# Usage: factory-start.sh <team-type> <project-dir> "<prompt>" [tier]
#   team-type: eng | eng-quick | pm | pm-eng | verify | pm-verify
#   tier:      trivial | standard | full | critical (default: full)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

if [ $# -lt 3 ]; then
  echo "Usage: $0 <team-type> <project-dir> \"<prompt>\" [tier]"
  echo "Teams: eng | eng-quick | pm | pm-eng | verify | pm-verify"
  exit 1
fi

TEAM_TYPE="$1"
PROJECT_DIR="$2"
PROMPT="$3"
TIER="${4:-full}"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
AHE_HOME="${AHE_HOME:-/root/.hermes/agents}"
SESSION_NAME="dark-factory-$(basename $PROJECT_DIR)-$(date +%s)"
TELEMETRY_DIR="/tmp/ahe/telemetry/$SESSION_NAME"
LOG_DIR="$AHE_HOME/dark-factory/logs/$SESSION_NAME"
WORKTREE_DIR="$AHE_HOME/dark-factory/worktrees/$SESSION_NAME"
HARNESS_YAML="$AHE_HOME/harness.yaml"

mkdir -p "$TELEMETRY_DIR" "$LOG_DIR" "$WORKTREE_DIR"

# ---------------------------------------------------------------------------
# Load tier config from harness.yaml (simple YAML parser)
# ---------------------------------------------------------------------------
parse_yaml_value() {
  local key="$1"
  grep -E "^  $key:" "$HARNESS_YAML" 2>/dev/null | head -1 | sed 's/.*: *"\{0,1\}\(.*\)"\{0,1\}$/\1/' | xargs
}

MODEL=$(parse_yaml_value "model" < <(awk "/^  $TIER:/{flag=1;next} /^  [a-z]/{flag=0} flag" "$HARNESS_YAML" 2>/dev/null) || echo "opencode-go/deepseek-v4-flash")
TIMEOUT=$(grep -A10 "  $TIER:" "$HARNESS_YAML" 2>/dev/null | grep "timeout_sec:" | head -1 | sed 's/.*: //' | xargs || echo "180")

# ---------------------------------------------------------------------------
# Team definitions
# ---------------------------------------------------------------------------
declare -A TEAMS
TEAMS[eng]="opencode-spec|spec|/root/.hermes/agents/opencode/opencode-spec.md|build
opencode-builder|builder|/root/.hermes/agents/opencode/opencode-builder.md|build
opencode-reviewer|reviewer|/root/.hermes/agents/opencode/opencode-reviewer.md|build
pi-quality-gate|quality-gate|/root/.hermes/agents/pi/pi-quality-gate.md|verify
opencode-ship|ship|/root/.hermes/agents/opencode/opencode-ship.md|build"
TEAMS[eng-quick]="opencode-builder|builder|/root/.hermes/agents/opencode/opencode-builder.md|build
opencode-reviewer|reviewer|/root/.hermes/agents/opencode/opencode-reviewer.md|build
pi-quality-gate|quality-gate|/root/.hermes/agents/pi/pi-quality-gate.md|verify"
TEAMS[pm]="opencode-pm-discover|discover|/root/.hermes/agents/opencode/opencode-pm-discover.md|build
opencode-pm-strategy|strategy|/root/.hermes/agents/opencode/opencode-pm-strategy.md|build
opencode-pm-prd|prd|/root/.hermes/agents/opencode/opencode-pm-prd.md|build
pi-pm-prd-review|prd-review|/root/.hermes/agents/pi/pi-pm-prd-review.md|verify"
TEAMS[pm-eng]="opencode-pm-discover|discover|/root/.hermes/agents/opencode/opencode-pm-discover.md|build
opencode-pm-prd|prd|/root/.hermes/agents/opencode/opencode-pm-prd.md|build
opencode-spec|spec|/root/.hermes/agents/opencode/opencode-spec.md|build
opencode-builder|builder|/root/.hermes/agents/opencode/opencode-builder.md|build
pi-quality-gate|quality-gate|/root/.hermes/agents/pi/pi-quality-gate.md|verify"
TEAMS[verify]="pi-security|security|/root/.hermes/agents/pi/pi-security.md|verify
pi-test-coverage|test-cov|/root/.hermes/agents/pi/pi-test-coverage.md|verify
pi-quality-gate|quality-gate|/root/.hermes/agents/pi/pi-quality-gate.md|verify
pi-observability|observability|/root/.hermes/agents/pi/pi-observability.md|verify"
TEAMS[pm-verify]="pi-pm-prd-review|prd-review|/root/.hermes/agents/pi/pi-pm-prd-review.md|verify
pi-pm-strategy-check|strategy|/root/.hermes/agents/pi/pi-pm-strategy-check.md|verify
pi-pm-market-fit|market-fit|/root/.hermes/agents/pi/pi-pm-market-fit.md|verify
pi-pm-discovery-audit|audit|/root/.hermes/agents/pi/pi-pm-discovery-audit.md|verify"

TEAM="${TEAMS[$TEAM_TYPE]:-}"
if [ -z "$TEAM" ]; then
  echo -e "${RED}Unknown team type: $TEAM_TYPE${NC}"; exit 1
fi
if [ ! -d "$PROJECT_DIR" ]; then
  echo -e "${RED}Project directory not found: $PROJECT_DIR${NC}"; exit 1
fi

# ---------------------------------------------------------------------------
# Write session manifest (JSONL header)
# ---------------------------------------------------------------------------
cat > "$TELEMETRY_DIR/00-session.jsonl" <<EOF
{"event":"session_start","session":"$SESSION_NAME","team":"$TEAM_TYPE","tier":"$TIER","model":"$MODEL","timeout_sec":$TIMEOUT,"project":"$PROJECT_DIR","prompt":"$PROMPT","timestamp":"$(date -Iseconds)"}
EOF

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  AHE Dark Factory${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "  Session:  $SESSION_NAME"
echo -e "  Team:     $TEAM_TYPE (tier: $TIER)"
echo -e "  Model:    $MODEL"
echo -e "  Timeout:  ${TIMEOUT}s"
echo -e "  Project:  $PROJECT_DIR"
echo -e "  Telemetry: $TELEMETRY_DIR"
echo -e "  Logs:     $LOG_DIR"

# ---------------------------------------------------------------------------
# Launch tmux session
# ---------------------------------------------------------------------------
tmux new-session -d -s "$SESSION_NAME" -c "$PROJECT_DIR" -n agents
tmux set-option -t "$SESSION_NAME" status-left " AHE:$TEAM_TYPE:$TIER "
tmux set-option -t "$SESSION_NAME" status-right "#{pane_title}"

pane=0
while IFS='|' read -r agent_name pane_title config_file agent_type; do
  [ -z "$agent_name" ] && continue
  agent_name=$(echo "$agent_name" | xargs)
  pane_title=$(echo "$pane_title" | xargs)
  config_file=$(echo "$config_file" | xargs)
  agent_type=$(echo "$agent_type" | xargs)

  # Construct the telemetry wrapper command
  TELEMETRY_FILE="$TELEMETRY_DIR/$(printf '%02d' $pane)-${agent_name}.jsonl"
  LOG_FILE="$LOG_DIR/$(printf '%02d' $pane)-${agent_name}.log"

  # The agent runs inside a wrapper that captures stdout to both
  # a plain log file AND a JSONL telemetry stream
  WRAPPER_CMD=$(cat <<WRAPPER
cat $config_file > /tmp/ahe/${SESSION_NAME}-${agent_name}.md
echo "[AHE] Agent: $agent_name | Type: $agent_type | Tier: $TIER | Model: $MODEL"
echo "[AHE] Config: $(wc -l < $config_file) lines loaded"
echo "[AHE] Starting at $(date -Iseconds)"
echo '{"event":"agent_start","agent":"$agent_name","type":"$agent_type","tier":"$TIER","timestamp":"$(date -Iseconds)"}' >> "$TELEMETRY_FILE"
opencode run --model "$MODEL" "\$(cat /tmp/ahe/${SESSION_NAME}-${agent_name}.md) $PROMPT" 2>&1 | tee -a "$LOG_FILE" | while IFS= read -r line; do
  echo "{\"event\":\"agent_output\",\"agent\":\"$agent_name\",\"line\":\"\$(echo \$line | sed 's/\"/\\\\\"/g')\",\"timestamp\":\"\$(date -Iseconds)\"}" >> "$TELEMETRY_FILE"
  echo "\$line"
done
EXIT_CODE=\$?
echo "{\"event\":\"agent_exit\",\"agent\":\"$agent_name\",\"exit_code\":\$EXIT_CODE,\"timestamp\":\"\$(date -Iseconds)\"}" >> "$TELEMETRY_FILE"
echo "[AHE] Exit code: \$EXIT_CODE"
WRAPPER
)

  if [ "$pane" -eq 0 ]; then
    tmux rename-window -t "$SESSION_NAME:0" "agents"
    tmux send-keys -t "$SESSION_NAME:0.0" "$WRAPPER_CMD" Enter
  else
    tmux split-window -h -t "$SESSION_NAME:0"
    tmux select-layout -t "$SESSION_NAME:0" tiled 2>/dev/null || true
    tmux send-keys -t "$SESSION_NAME:0.$pane" "$WRAPPER_CMD" Enter
  fi

  tmux select-pane -t "$SESSION_NAME:0.$pane" -T "$pane_title"
  echo -e "  ${GREEN}[Pane $((pane+1))]${NC} $agent_name ($agent_type)"

  pane=$((pane + 1))
done <<< "$TEAM"

tmux select-layout -t "$SESSION_NAME:0" tiled 2>/dev/null || true

# ---------------------------------------------------------------------------
# Write exit-state watcher (runs in background, checks JSONL for verdicts)
# ---------------------------------------------------------------------------
cat > "$TELEMETRY_DIR/99-watcher.sh" <<'WATCHER'
#!/usr/bin/env bash
# Watches JSONL telemetry for gate verdicts and exits when pipeline completes
SESSION_DIR="$1"
POLL_INTERVAL=5
MAX_WAIT=3600  # 1 hour
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
  # Check for quality-gate exit
  QUALS=$(grep '"agent":"quality-gate"' "$SESSION_DIR"/*.jsonl 2>/dev/null | grep 'agent_exit' | tail -1 || echo "")
  if [ -n "$QUALS" ]; then
    EXIT=$(echo "$QUALS" | grep -o '"exit_code":[0-9]*' | cut -d: -f2)
    echo "[WATCHER] quality-gate exited with code $EXIT"
    if [ "$EXIT" -eq 0 ]; then
      echo "[WATCHER] PIPELINE COMPLETE — quality gate PASSED"
    else
      echo "[WATCHER] PIPELINE BLOCKED — quality gate FAILED"
    fi
    break
  fi

  # Check all agents completed
  STARTED=$(grep -c '"event":"agent_start"' "$SESSION_DIR"/*.jsonl 2>/dev/null || echo 0)
  EXITED=$(grep -c '"event":"agent_exit"' "$SESSION_DIR"/*.jsonl 2>/dev/null || echo 0)
  if [ "$STARTED" -gt 0 ] && [ "$STARTED" -eq "$EXITED" ]; then
    echo "[WATCHER] All $STARTED agents completed"
    break
  fi

  sleep $POLL_INTERVAL
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

# Write summary
echo "{\"event\":\"pipeline_complete\",\"elapsed_sec\":$ELAPSED,\"agents_started\":$STARTED,\"agents_exited\":$EXITED,\"timestamp\":\"$(date -Iseconds)\"}" > "$SESSION_DIR/99-summary.jsonl"
WATCHER
chmod +x "$TELEMETRY_DIR/99-watcher.sh"
nohup bash "$TELEMETRY_DIR/99-watcher.sh" "$TELEMETRY_DIR" > "$LOG_DIR/watcher.log" 2>&1 &

echo ""
echo -e "${GREEN}Factory started.${NC}"
echo "  Attach:   tmux attach -t $SESSION_NAME"
echo "  Status:   $AHE_HOME/dark-factory/scripts/factory-status.sh"
echo "  Telemetry: tail -f $TELEMETRY_DIR/*.jsonl"
echo "  Watcher:  tail -f $LOG_DIR/watcher.log"
