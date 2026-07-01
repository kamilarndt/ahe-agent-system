#!/usr/bin/env bash
# Dark Factory — Setup: validate prerequisites
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Dark Factory Setup ==="
echo ""

PASS=0
FAIL=0

check() {
  local tool=$1
  local min_version=$2
  local cmd=$3

  if command -v "$tool" &>/dev/null; then
    echo -e "${GREEN}✓${NC} $tool found"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}✗${NC} $tool NOT found (min: $min_version) — install: $cmd"
    FAIL=$((FAIL + 1))
  fi
}

check "tmux" "3.0+" "apt install tmux"
check "git" "2.30+" "apt install git"

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  echo -e "${YELLOW}Install missing tools and re-run.${NC}"
  exit 1
fi

echo -e "${GREEN}All prerequisites met. Dark Factory ready.${NC}"

# Create directories
mkdir -p ~/.hermes/agents/dark-factory/logs
mkdir -p ~/.hermes/agents/dark-factory/worktrees
echo "Directories: ~/.hermes/agents/dark-factory/{logs,worktrees}"
