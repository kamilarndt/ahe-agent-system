#!/usr/bin/env bash
# Install OpenCode specialist agents
# Usage: bash install-opencode-agents.sh [project-path]
# Default: installs into current directory's agents/ folder

set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
AGENTS_DIR="$PROJECT_DIR/agents"
SOURCE_DIR="/root/.hermes/agents/opencode"

echo "Installing OpenCode specialist agents to $AGENTS_DIR"
mkdir -p "$AGENTS_DIR"

# Map agent file -> agent name (inferred from frontmatter by OpenCode)
AGENTS=(
  "opencode-spec.md"
  "opencode-builder.md"
  "opencode-reviewer.md"
  "opencode-architect.md"
  "opencode-perf.md"
  "opencode-ship.md"
  "opencode-migration.md"
)

for agent_file in "${AGENTS[@]}"; do
  src="$SOURCE_DIR/$agent_file"
  if [ -f "$src" ]; then
    echo "  Installing $agent_file..."
    cp "$src" "$AGENTS_DIR/"
  else
    echo "  WARNING: $agent_file not found at $src"
  fi
done

echo ""
echo "Done! Agents installed to $AGENTS_DIR"
echo ""
echo "To use an agent: opencode --agent <agent-name>"
echo ""
echo "Available agents:"
for agent_file in "${AGENTS[@]}"; do
  name="${agent_file%.md}"
  name="${name#opencode-}"
  echo "  opencode --agent $name"
done
