#!/usr/bin/env python3
"""
Agentic Workflow Orchestrator — Hermes Multi-Agent Pipeline

Usage:
    python3 orchestrator.py init <feature>          # Initialize workflow
    python3 orchestrator.py status <feature>        # Show progress
    python3 orchestrator.py next <feature>          # What phase is ready
    python3 orchestrator.py context <feature> <phase>  # Generate context for delegate_task
    python3 orchestrator.py complete <feature> <phase>  # Mark phase done
    python3 orchestrator.py block <feature> <phase> <reason>  # Mark phase blocked
    python3 orchestrator.py summary <feature>       # Full summary (for Pi quality-gate)

DESIGN:

    Hermes (orchestrator master)
      │
      ├── Krok 1: orchestrator init "user-auth"
      ├── Krok 2: deleguje do agentów ręcznie przez delegate_task
      │     (orchestrator generuje context na każdą fazę)
      ├── Krok 3: sprawdza status, blokuje/przechodzi dalej
      └── Krok 4: final verdict z pi-quality-gate

    Każdy agent:
      - Dostaje context z orchestrator context <feature> <phase>
      - Pisze output do .hermes/workflow/<feature>/<phase>/
      - Jego summary trafia do workflow_summary.md
      - State jest w state.json (czytelny dla następnych agentów)
"""

import sys
import json
from pathlib import Path
from workflow_state import WorkflowState


def cmd_init(args):
    """Initialize a new workflow for a feature."""
    feature = args[0]
    project_dir = args[1] if len(args) > 1 else os.getcwd()
    wf = WorkflowState(feature, root=Path(project_dir))
    print(json.dumps({
        "status": "initialized",
        "feature": feature,
        "path": str(wf.root),
        "phases": WorkflowState.PHASES,
        "next_phase": wf.get_next_phase(),
    }, indent=2))


def cmd_status(args):
    """Show workflow status."""
    feature = args[0]
    wf = WorkflowState(feature)
    print(wf.summary())


def cmd_next(args):
    """Show the next ready phase + parallel groups."""
    feature = args[0]
    wf = WorkflowState(feature)
    next_phase = wf.get_next_phase()
    parallel_groups = wf.get_ready_parallel()
    
    result = {
        "next_sequential": next_phase,
        "parallel_groups": parallel_groups,
    }
    
    if next_phase:
        result["agent_options"] = _agent_for_phase(next_phase)
        result["dependencies_satisfied"] = wf.can_start(next_phase)
    
    print(json.dumps(result, indent=2))


def cmd_context(args):
    """Generate delegate_task context for a phase."""
    feature = args[0]
    phase = args[1]
    wf = WorkflowState(feature)
    
    if not wf.can_start(phase):
        print(json.dumps({
            "error": f"Cannot start {phase}: dependencies not satisfied",
            "phase_status": dict(wf.get_phase_status(phase)),
        }, indent=2))
        return 1
    
    wf.phase_start(phase)
    
    context = {
        "feature": feature,
        "phase": phase,
        "instruction": _instruction_for_phase(phase),
        "available_artifacts": {
            dep: wf.get_artifact(dep) or ""
            for dep in WorkflowState.DEPENDENCIES.get(phase, [])
        },
        "decisions": {
            dep: wf._state["decisions"].get(dep, {})
            for dep in WorkflowState.DEPENDENCIES.get(phase, [])
        },
        "phase_dir": str(wf.get_phase_dir(phase)),
        "state_file": str(wf.state_file),
        "project_root": str(Path.cwd()),
    }
    
    print(json.dumps(context, indent=2))


def cmd_complete(args):
    """Mark a phase as completed."""
    feature = args[0]
    phase = args[1]
    verdict = args[2] if len(args) > 2 else "pass"
    agent = args[3] if len(args) > 3 else None
    artifact = args[4] if len(args) > 4 else None
    
    wf = WorkflowState(feature)
    wf.phase_complete(phase, verdict=verdict, agent=agent, artifact=artifact)
    
    next_phase = wf.get_next_phase()
    parallel_groups = wf.get_ready_parallel()
    
    print(json.dumps({
        "status": f"{phase} completed with verdict '{verdict}'",
        "next_sequential": next_phase,
        "parallel_groups": parallel_groups,
    }, indent=2))


def cmd_block(args):
    """Mark a phase as blocked."""
    feature = args[0]
    phase = args[1]
    reason = " ".join(args[2:])
    
    wf = WorkflowState(feature)
    wf.phase_blocked(phase, reason)
    wf.phase_complete(phase, verdict="blocked")
    
    print(json.dumps({
        "status": f"{phase} blocked",
        "reason": reason,
        "blocked_phases": _find_blocked_downstream(wf, phase),
    }, indent=2))


def cmd_summary(args):
    """Generate full summary for quality gate or handoff."""
    feature = args[0]
    wf = WorkflowState(feature)
    
    summary = {
        "feature": feature,
        "overall_status": "completed" if wf.get_phase_status("09-quality").get("verdict") else "in_progress",
        "phases": {},
    }
    
    for phase in WorkflowState.PHASES:
        ps = wf._state["phases"].get(phase, {})
        artifacts = list(wf.get_phase_dir(phase).iterdir()) if wf.get_phase_dir(phase).exists() else []
        summary["phases"][phase] = {
            "status": ps.get("status", "pending"),
            "verdict": ps.get("verdict", ""),
            "agent": ps.get("agent", ""),
            "artifacts": [str(a.name) for a in artifacts],
        }
    
    print(json.dumps(summary, indent=2))


def _agent_for_phase(phase: str) -> dict:
    """Map phase name to agent to invoke."""
    mapping = {
        "01-spec": {
            "agent_type": "opencode",
            "agent_name": "opencode-spec",
            "tool": "opencode --agent spec",
        },
        "02-arch": {
            "agent_type": "opencode",
            "agent_name": "opencode-architect",
            "tool": "opencode --agent architect",
        },
        "03-build": {
            "agent_type": "opencode",
            "agent_name": "opencode-builder",
            "tool": "opencode --agent build",
        },
        "04-review": {
            "agent_type": "opencode",
            "agent_name": "opencode-reviewer",
            "tool": "opencode --agent plan",
        },
        "05-security": {
            "agent_type": "pi",
            "agent_name": "pi-security",
            "tool": "delegate_task with pi-security persona",
        },
        "06-coverage": {
            "agent_type": "pi",
            "agent_name": "pi-test-coverage",
            "tool": "delegate_task with pi-test-coverage persona",
        },
        "07-observability": {
            "agent_type": "pi",
            "agent_name": "pi-observability",
            "tool": "delegate_task with pi-observability persona",
        },
        "08-fix": {
            "agent_type": "opencode",
            "agent_name": "opencode-builder",
            "tool": "opencode --agent build (fix mode)",
        },
        "09-quality": {
            "agent_type": "pi",
            "agent_name": "pi-quality-gate",
            "tool": "delegate_task with pi-quality-gate persona",
        },
    }
    return mapping.get(phase, {})


def _instruction_for_phase(phase: str) -> str:
    """Generate human-readable instruction for the agent in this phase."""
    instructions = {
        "01-spec": (
            "You are opencode-spec. Define the specification for this feature. "
            "Interview a stakeholder (if needed), produce PRD.md and task-breakdown.md. "
            "Write outputs to the phase directory."
        ),
        "02-arch": (
            "You are opencode-architect. Read the PRD from 01-spec. "
            "Design architecture: API contracts, ADRs, data model, module boundaries. "
            "Write outputs to docs/adr/ and contracts files."
        ),
        "03-build": (
            "You are opencode-builder. Read the PRD and architecture. "
            "Implement tests-first (TDD), one task at a time. "
            "Commit after each task. Write build summary."
        ),
        "04-review": (
            "You are opencode-reviewer. Read all build outputs. "
            "Conduct 5-axis review (correctness, readability, architecture, security, performance). "
            "Write review-report.md with APPROVE or REQUEST CHANGES."
        ),
        "05-security": (
            "You are pi-security. Audit the code for OWASP Top 10 vulnerabilities. "
            "Write security-audit.md with severity-classified findings. "
            "You MAY read code but MUST NOT write or fix it."
        ),
        "06-coverage": (
            "You are pi-test-coverage. Analyze tests for gaps. "
            "Write coverage-gaps.md with priority-ordered recommendations. "
            "You MAY read code/tests but MUST NOT write them."
        ),
        "07-observability": (
            "You are pi-observability. Audit logging, metrics, tracing, alerting. "
            "Write observability-audit.md with PASS/WARN/FAIL per category."
        ),
        "08-fix": (
            "You are opencode-builder (fix mode). Read the security, coverage, and review reports. "
            "Fix all CRITICAL and HIGH issues found. "
            "Write fix-summary.md listing each issue and the fix applied."
        ),
        "09-quality": (
            "You are pi-quality-gate. This is the FINAL gate before merge. "
            "Read all prior phase summaries. Produce quality-gate.md with go/no-go verdict. "
            "BLOCK if any critical issues remain. "
            "You MAY read all prior artifacts but MUST NOT write code."
        ),
    }
    return instructions.get(phase, f"Execute phase {phase} according to its agent definition.")


def _find_blocked_downstream(wf: WorkflowState, blocked_phase: str) -> list:
    """Find all phases that are blocked by this blocker."""
    downstream = []
    for phase in WorkflowState.PHASES:
        deps = WorkflowState.DEPENDENCIES.get(phase, [])
        if blocked_phase in deps:
            downstream.append(phase)
    return downstream


def main():
    if len(sys.argv) < 3:
        print("Usage:")
        print("  orchestrator.py init <feature>")
        print("  orchestrator.py status <feature>")
        print("  orchestrator.py next <feature>")
        print("  orchestrator.py context <feature> <phase>")
        print("  orchestrator.py complete <feature> <phase> [verdict] [agent] [artifact]")
        print("  orchestrator.py block <feature> <phase> <reason...>")
        print("  orchestrator.py summary <feature>")
        sys.exit(1)

    command = sys.argv[1]
    args = sys.argv[2:]

    commands = {
        "init": cmd_init,
        "status": cmd_status,
        "next": cmd_next,
        "context": cmd_context,
        "complete": cmd_complete,
        "block": cmd_block,
        "summary": cmd_summary,
    }

    handler = commands.get(command)
    if not handler:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)

    try:
        result = handler(args)
        sys.exit(result if isinstance(result, int) else 0)
    except Exception as e:
        print(json.dumps({"error": str(e)}, indent=2), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
