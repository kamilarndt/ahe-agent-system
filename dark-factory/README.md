# Dark Factory

Persistent, autonomous AI agent teams running on a remote/headless machine via tmux.
Adapted from [cheddarfox/safe-agentic-workflow](https://github.com/cheddarfox/safe-agentic-workflow) — SAFe multi-agent methodology.

## Architecture

```
Hermes (orchestrator)
  │
  ├── tmux session: dark-factory-<session>
  │   ├── [1] Spec Agent          (opencode-spec)
  │   ├── [2] Builder Agent       (opencode-builder)
  │   ├── [3] Reviewer Agent      (opencode-reviewer)
  │   ├── [4] Quality Gate        (pi-quality-gate)
  │   └── [5] Ship Agent          (opencode-ship)
  │
  └── ~/.hermes/agents/dark-factory/
        logs/<session>/       <- per-agent output logs
        worktrees/<session>/  <- per-agent git worktrees
```

## Usage

```bash
# 1. Prerequisites check
bash ~/.hermes/agents/dark-factory/scripts/factory-setup.sh

# 2. Start a factory for a feature
bash ~/.hermes/agents/dark-factory/scripts/factory-start.sh eng <project-dir> "Add auth module"

# 3. Status dashboard
bash ~/.hermes/agents/dark-factory/scripts/factory-status.sh

# 4. Attach to a specific agent pane (observe only)
bash ~/.hermes/agents/dark-factory/scripts/factory-attach.sh dark-factory-<session> 2

# 5. Stop all agents gracefully
bash ~/.hermes/agents/dark-factory/scripts/factory-stop.sh dark-factory-<session>
```

## Agent Teams

| Team Type | Agents | When |
|-----------|--------|------|
| `eng` (full) | spec, builder, reviewer, quality-gate, ship | Full feature from spec to ship |
| `eng-quick` | builder, reviewer, quality-gate | Bugfix / small change |
| `pm` | discover, strategy, prd, prd-review | Discovery + PRD only |
| `pm-eng` | discover, prd, spec, builder, quality-gate | Full PM → ENG pipeline |
| `verify` | security, test-coverage, quality-gate, observability | Pre-release audit |
| `pm-verify` | prd-review, strategy-check, market-fit, discovery-audit | PM quality check |

## Status Dashboard

```
========================================
  Dark Factory Status Dashboard
========================================
Session: dark-factory-auth-module-abc123
  Created: 2026-07-01 10:15:00
  Panes:
    [1] opencode-spec          active        ← Running, recent output
    [2] opencode-builder       idle (180s)   ← Waiting for spec
    [3] opencode-reviewer      waiting       ← Not started
    [4] pi-quality-gate        dead          ← Exited: APPROVED
    [5] opencode-ship          waiting       ← Not started
```

## Logs

```
~/.hermes/agents/dark-factory/logs/dark-factory-<session>/
├── 1-opencode-spec.log
├── 2-opencode-builder.log
├── 3-opencode-reviewer.log
├── 4-pi-quality-gate.log
└── 5-opencode-ship.log
```
