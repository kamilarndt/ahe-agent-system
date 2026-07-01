#!/usr/bin/env bash
# =============================================================================
# ahe-init — Universal AHE Harness Bootstrap
# Run in any project directory to set up the AHE agent harness.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kamilarndt/ahe-agent-system/main/ahe-init.sh | bash
#   # or:
#   bash <(curl -fsSL https://tinyurl.com/ahe-init)
#
# What it does:
#   1. Creates agents/ directory with OpenCode + Pi agent stubs
#   2. Generates harness.yaml with your project name and model choice
#   3. Creates .ahe/ for logs and cache, .spec/ for specs
#   4. Initializes justfile for task running
#   5. Installs just (if missing) and Playwright (if needed for QA)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  AHE — Universal Harness Bootstrap${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ── Project detection ──
PROJECT_NAME="${1:-$(basename $(pwd))}"
PROJECT_SHORT="${PROJECT_NAME//-/_}"

echo -e "  Project: ${GREEN}${PROJECT_NAME}${NC}"
echo -e "  Dir:     $(pwd)"
echo ""

# ── Check prerequisites ──
PREREQS=0
for cmd in git opencode; do
  if command -v $cmd &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $cmd found"
  else
    echo -e "  ${RED}✗${NC} $cmd not found — install it first"
    PREREQS=$((PREREQS+1))
  fi
done

if [ "$PREREQS" -gt 0 ]; then
  echo -e "\n${RED}Install missing prerequisites and re-run.${NC}"
  echo "  opencode: npm i -g opencode-ai"
  exit 1
fi

# ── Create directory structure ──
echo -e "\n${CYAN}Creating harness directories...${NC}"
mkdir -p agents/opencode agents/pi .ahe/logs .ahe/cache .spec
echo -e "  ${GREEN}✓${NC} agents/opencode/"
echo -e "  ${GREEN}✓${NC} agents/pi/"
echo -e "  ${GREEN}✓${NC} .ahe/{logs,cache}/"
echo -e "  ${GREEN}✓${NC} .spec/"

# ── Generate harness.yaml ──
cat > harness.yaml <<HARNESS
harness_version: "1.0.0"
project_name: "${PROJECT_NAME}"

models:
  default: "groq/qwen/qwen3-32b"
  cheap: "groq/qwen/qwen3.6-27b"
  quality: "nvidia/deepseek-ai/deepseek-v4-pro"

agents:
  opencode-spec: true
  opencode-builder: true
  opencode-reviewer: true
  pi-quality-gate: true

topology:
  phases:
    - name: "spec"
      agent: "opencode-spec"
    - name: "build"
      agent: "opencode-builder"
    - name: "review"
      agent: "opencode-reviewer"
    - name: "verify"
      agent: "pi-quality-gate"
      gate: true

paths:
  specs: ".spec/"
  agents: "agents/"
  logs: ".ahe/logs/"
  cache: ".ahe/cache/"
HARNESS
echo -e "  ${GREEN}✓${NC} harness.yaml generated"

# ── Generate justfile ──
cat > justfile <<'JUSTFILE'
# ──────────────────────────────────────────────
# AHE — Project Harness
# ──────────────────────────────────────────────

default:
  @just --list

pipeline task="":
  opencode run --agent opencode-spec "{{task}}"
  opencode run --agent opencode-builder "Implement the spec"
  opencode run --agent opencode-reviewer "Review the implementation"
  opencode run --agent pi-quality-gate "Gate check"

run agent prompt:
  opencode run --agent opencode-{{agent}} "{{prompt}}"

gate:
  opencode run --agent pi-quality-gate \
    "Read all recent changes. Produce <fusion-verdict> with APPROVE | BLOCK."
JUSTFILE
echo -e "  ${GREEN}✓${NC} justfile generated"

# ── Install agent files from GitHub (or copy local) ──
echo -e "\n${CYAN}Downloading agent definitions...${NC}"
AHE_REPO="https://raw.githubusercontent.com/kamilarndt/ahe-agent-system/main"

for agent in opencode-spec opencode-builder opencode-reviewer opencode-ship; do
  curl -sfL "${AHE_REPO}/opencode/${agent}.md" -o "agents/opencode/${agent}.md" 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} ${agent}.md" || \
    echo -e "  ${YELLOW}⚠${NC} ${agent}.md (fallback — create manually)"
done

for agent in pi-quality-gate; do
  curl -sfL "${AHE_REPO}/pi/${agent}.md" -o "agents/pi/${agent}.md" 2>/dev/null && \
    echo -e "  ${GREEN}✓${NC} ${agent}.md" || \
    echo -e "  ${YELLOW}⚠${NC} ${agent}.md (fallback — create manually)"
done

# ── Git ignore ──
if [ -f .gitignore ]; then
  grep -q "\.ahe/" .gitignore || echo -e "\n# AHE harness\n.ahe/" >> .gitignore
else
  echo -e "# AHE harness\n.ahe/" > .gitignore
fi
echo -e "  ${GREEN}✓${NC} .gitignore updated"

# ── Summary ──
echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  AHE Harness ready in $(pwd)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo "    1. Edit harness.yaml to adjust agents and models"
echo "    2. Run:  just pipeline \"Add user authentication\""
echo "    3. Run:  just gate"
echo ""
echo -e "  ${YELLOW}Commands:${NC}"
echo "    just               — list all commands"
echo "    just pipeline ...  — run full spec→build→review→verify"
echo "    just run <a> <p>   — run a single agent"
echo "    just gate          — run quality gate only"
echo ""
