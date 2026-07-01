#!/usr/bin/env bash
# Install multi-agent workflow orchestration
# Usage: bash install-workflow.sh [project-path]
set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
AGENTS_SRC="/root/.hermes/agents"
WORKFLOW_DIR="$PROJECT_DIR/.hermes/workflow"

echo "============================================"
echo "  Hermes Multi-Agent Workflow Installer"
echo "============================================"
echo ""

# ── 1. Create workflow directory structure ──
echo "[1/4] Creating workflow directory structure..."
mkdir -p "$WORKFLOW_DIR"
mkdir -p "$WORKFLOW_DIR"/{01-spec,02-arch,03-build,04-review}
mkdir -p "$WORKFLOW_DIR"/{05-security,06-coverage,07-observability}
mkdir -p "$WORKFLOW_DIR"/{08-fix,09-quality}
echo "  -> $WORKFLOW_DIR/"
echo "  -> phased subdirectories created"

# ── 2. Copy orchestrator scripts ──
echo "[2/4] Installing orchestrator scripts..."
mkdir -p "$PROJECT_DIR/.hermes/scripts"
cp "$AGENTS_SRC/scripts/workflow_state.py" "$PROJECT_DIR/.hermes/scripts/"
cp "$AGENTS_SRC/scripts/orchestrator.py" "$PROJECT_DIR/.hermes/scripts/"
chmod +x "$PROJECT_DIR/.hermes/scripts/"*.py
echo "  -> .hermes/scripts/workflow_state.py"
echo "  -> .hermes/scripts/orchestrator.py"

# ── 3. Create ~/.local/bin symlinks (CLI wrappers) ──
echo "[3/4] Creating CLI wrappers..."
mkdir -p ~/.local/bin

cat > ~/.local/bin/ahe-workflow << 'WRAPPER'
#!/usr/bin/env bash
# ahe-workflow — Agentic Harness Engineering workflow orchestrator
exec python3 /root/.hermes/agents/scripts/orchestrator.py "$@"
WRAPPER
chmod +x ~/.local/bin/ahe-workflow

cat > ~/.local/bin/ahe-init << 'WRAPPER'
#!/usr/bin/env bash
# ahe-init — Initialize a new multi-agent workflow
exec python3 /root/.hermes/agents/scripts/orchestrator.py init "$@"
WRAPPER
chmod +x ~/.local/bin/ahe-init

cat > ~/.local/bin/ahe-status << 'WRAPPER'
#!/usr/bin/env bash
# ahe-status — Show workflow status  
exec python3 /root/.hermes/agents/scripts/orchestrator.py status "$@"
WRAPPER
chmod +x ~/.local/bin/ahe-status

cat > ~/.local/bin/ahe-next << 'WRAPPER'
#!/usr/bin/env bash
# ahe-next — Show next ready phase
exec python3 /root/.hermes/agents/scripts/orchestrator.py next "$@"
WRAPPER
chmod +x ~/.local/bin/ahe-next

echo "  -> ~/.local/bin/ahe-workflow (orchestrator CLI)"
echo "  -> ~/.local/bin/ahe-init     (init workflow)"
echo "  -> ~/.local/bin/ahe-status   (show progress)"
echo "  -> ~/.local/bin/ahe-next     (next phase)"

# ── 4. Verify installation ──
echo "[4/4] Verifying installation..."
echo ""

PYTHON_OK=$(python3 -c "import sys; sys.path.insert(0, '/root/.hermes/agents/scripts'); from workflow_state import WorkflowState; print('OK')" 2>&1)
echo "  workflow_state.py ... $PYTHON_OK"

ORCH_OK=$(python3 -c "import sys; sys.path.insert(0, '/root/.hermes/agents/scripts'); from orchestrator import main; print('OK')" 2>&1)
echo "  orchestrator.py   ... $ORCH_OK"

# Test init with a demo feature
DEMO_OUT=$(python3 /root/.hermes/agents/scripts/orchestrator.py init test-install 2>&1)
echo "  workflow init test ... $DEMO_OUT" | head -3

# Cleanup test
rm -rf "$PROJECT_DIR/.hermes/workflow/test-install"

echo ""
echo "============================================"
echo "  Installation complete!"
echo "============================================"
echo ""
echo "Quick start:"
echo "  cd $PROJECT_DIR"
echo "  ahe-init user-auth     # Initialize workflow for 'user-auth' feature"
echo "  ahe-status user-auth   # Check progress"
echo "  ahe-next user-auth     # See what's ready to run"
echo ""
echo "Then from Hermes:"
echo "  1. ahe-init <feature>"
echo "  2. delegate_task(goal='...', context=exec('ahe-context <feature> <phase>'))"
echo "  3. ahe-complete <feature> <phase> pass opencode-builder"
echo "  4. Repeat until quality-gate passes"
echo ""

# ── 5. Check Hermes skills path ──
if [ -d "/root/.hermes/skills" ]; then
    echo "Skills directory found at ~/.hermes/skills/"
    echo "  -> Skills will be available in next Hermes session"
fi

echo ""
echo "Your 11 agents are in $AGENTS_SRC:"
echo "  OpenCode: spec, builder, architect, reviewer, perf, ship, migration"
echo "  Pi:       security, test-coverage, quality-gate, observability"
echo ""
echo "Each agent now has Communication Protocol (Input/Output/Error contracts)."
