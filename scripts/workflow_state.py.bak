#!/usr/bin/env python3
"""
Workflow State Manager — Hermes Agent Orchestration

Śledzi stan faz, artefaktów i decyzji między agentami.
Każda faza produkuje artefakt, następna faza go konsumuje.

Usage:
    from workflow_state import WorkflowState
    wf = WorkflowState("user-auth")
    wf.phase_start("01-spec")
    wf.phase_complete("01-spec", verdict="pass", artifact=".spec/PRD.md")
    wf.get_artifact("01-spec")  # → pliki z tej fazy
"""

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


DEFAULT_PROJECT_ROOT = Path.cwd()


def resolve_root(root: Optional[Path]) -> Path:
    """Resolve project root from arg or env or cwd."""
    if root:
        return Path(root).resolve()
    env_root = os.environ.get("HERMES_PROJECT_ROOT")
    if env_root:
        return Path(env_root).resolve()
    return DEFAULT_PROJECT_ROOT


class WorkflowState:
    """
    Stan wieloagentowego workflow.

    Struktura katalogów:
        .hermes/workflow/<feature>/
        ├── 01-spec/           PRD.md, task-breakdown.md
        ├── 02-arch/           ADR-*.md, openapi.yaml
        ├── 03-build/          kod + testy
        ├── 04-review/         review-report.md
        ├── 05-security/       security-audit.md
        ├── 06-coverage/       coverage-gaps.md
        ├── 07-observability/  observability-audit.md
        ├── 08-fix/            fix-summary.md
        ├── 09-quality/        quality-gate.md
        └── state.json         maszyna stanów
    """

    PHASES = [
        "01-spec",
        "02-arch",
        "03-build",
        "04-review",
        "05-security",
        "06-coverage",
        "07-observability",
        "08-fix",
        "09-quality",
    ]

    # Topologia zależności: co musi być gotowe zanim faza wystartuje
    DEPENDENCIES = {
        "01-spec": [],
        "02-arch": ["01-spec"],
        "03-build": ["01-spec", "02-arch"],
        "04-review": ["03-build"],
        "05-security": ["03-build"],
        "06-coverage": ["03-build"],
        "07-observability": ["03-build"],
        "08-fix": ["04-review", "05-security", "06-coverage", "07-observability"],
        "09-quality": ["08-fix"],
    }

    # Równoległe fazy (mogą lecieć jednocześnie)
    PARALLEL_GROUPS = [
        ["04-review"],
        ["05-security", "06-coverage", "07-observability"],  # fan-out
    ]

    def __init__(self, feature: str, root: Optional[Path] = None):
        self.feature = feature.replace(" ", "-").lower()
        project_root = resolve_root(root)
        self.project_root = project_root
        self.root = project_root / ".hermes" / "workflow" / self.feature
        self.state_file = self.root / "state.json"
        self._ensure_dirs()
        self._state = self._load()

    def _ensure_dirs(self):
        for phase in self.PHASES:
            (self.root / phase).mkdir(parents=True, exist_ok=True)

    def _load(self) -> dict:
        if self.state_file.exists():
            return json.loads(self.state_file.read_text())
        return {
            "feature": self.feature,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "phases": {},
            "artifacts": {},
            "decisions": {},
            "current_phase": None,
        }

    def _save(self):
        self.state_file.write_text(json.dumps(self._state, indent=2, default=str))

    # ── Phase lifecycle ──────────────────────────────────────

    def phase_start(self, phase: str):
        """Oznacz fazę jako w trakcie."""
        assert phase in self.PHASES, f"Unknown phase: {phase}"
        for dep in self.DEPENDENCIES.get(phase, []):
            dep_state = self._state["phases"].get(dep, {}).get("status")
            assert dep_state == "completed", \
                f"Dependency {dep} not completed (status={dep_state})"
        self._state["current_phase"] = phase
        self._state["phases"][phase] = {
            "status": "in_progress",
            "started_at": datetime.now(timezone.utc).isoformat(),
            "agent": None,
        }
        self._save()

    def phase_append_log(self, phase: str, entry: str):
        """Dodaj log entry do fazy."""
        if phase not in self._state["phases"]:
            self._state["phases"][phase] = {"status": "pending", "log": []}
        if "log" not in self._state["phases"][phase]:
            self._state["phases"][phase]["log"] = []
        self._state["phases"][phase]["log"].append({
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "message": entry,
        })
        self._save()

    def phase_complete(self, phase: str, verdict: str = "pass",
                       agent: str = None, artifact: str = None):
        """Oznacz fazę jako zakończoną."""
        assert verdict in ("pass", "fail", "blocked")
        self._state["phases"][phase]["status"] = "completed"
        self._state["phases"][phase]["completed_at"] = \
            datetime.now(timezone.utc).isoformat()
        self._state["phases"][phase]["verdict"] = verdict
        if agent:
            self._state["phases"][phase]["agent"] = agent
        if artifact:
            self._state["artifacts"][phase] = artifact
        self._state["current_phase"] = None
        self._save()

    def phase_blocked(self, phase: str, reason: str):
        """Oznacz fazę jako zablokowaną."""
        self._state["phases"][phase]["status"] = "blocked"
        self._state["phases"][phase]["blocked_at"] = \
            datetime.now(timezone.utc).isoformat()
        self._state["phases"][phase]["block_reason"] = reason
        self._save()

    # ── Decision records ─────────────────────────────────────

    def record_decision(self, phase: str, key: str, value, reason: str = ""):
        """Zapisz decyzję podjętą w fazie (np. 'go/no-go')."""
        if phase not in self._state["decisions"]:
            self._state["decisions"][phase] = {}
        self._state["decisions"][phase][key] = {
            "value": value,
            "reason": reason,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        self._save()

    # ── Queries ──────────────────────────────────────────────

    def get_phase_status(self, phase: str) -> dict:
        return self._state["phases"].get(phase, {"status": "pending"})

    def get_artifact(self, phase: str) -> Optional[str]:
        return self._state["artifacts"].get(phase)

    def get_phase_dir(self, phase: str) -> Path:
        return self.root / phase

    def get_decision(self, phase: str, key: str) -> Optional[dict]:
        return self._state["decisions"].get(phase, {}).get(key)

    def can_start(self, phase: str) -> bool:
        """Sprawdź czy wszystkie zależności są spełnione."""
        for dep in self.DEPENDENCIES.get(phase, []):
            if self._state["phases"].get(dep, {}).get("status") != "completed":
                return False
        return True

    def get_next_phase(self) -> Optional[str]:
        """Znajdź następną fazę do uruchomienia (kolejność faz)."""
        for phase in self.PHASES:
            status = self._state["phases"].get(phase, {}).get("status", "pending")
            if status != "pending":
                continue
            if self.can_start(phase):
                return phase
        return None

    def get_ready_parallel(self) -> list:
        """Zwraca listę faz gotowych do równoległego uruchomienia."""
        ready = []
        for group in self.PARALLEL_GROUPS:
            group_ready = []
            for phase in group:
                status = self._state["phases"].get(phase, {}).get("status", "pending")
                if status == "pending" and self.can_start(phase):
                    group_ready.append(phase)
            if group_ready:
                ready.append(group_ready)
        return ready

    def summary(self) -> str:
        """Pełny raport stanu."""
        lines = [f"Feature: {self.feature}"]
        lines.append("─" * 50)
        for phase in self.PHASES:
            ps = self._state["phases"].get(phase, {})
            status = ps.get("status", "pending")
            icon = {"completed": "✅", "in_progress": "▶", "blocked": "🔴",
                    "pending": "⏳"}.get(status, "❓")
            verdict = ps.get("verdict", "")
            agent = ps.get("agent", "")
            extra = f" [{verdict}]" if verdict else ""
            extra += f" ({agent})" if agent else ""
            lines.append(f"  {icon} {phase}{extra}")
        lines.append("─" * 50)
        return "\n".join(lines)

    def context_for(self, phase: str) -> str:
        """Wygeneruj context string dla delegate_task dla danej fazy."""
        context_parts = []
        # Dodaj artefakt zależności
        for dep in self.DEPENDENCIES.get(phase, []):
            artifact_path = self.get_artifact(dep)
            if artifact_path:
                context_parts.append(f"[{dep}] {artifact_path}")
        # Dodaj decyzje zależności
        for dep in self.DEPENDENCIES.get(phase, []):
            decisions = self._state["decisions"].get(dep, {})
            for k, v in decisions.items():
                context_parts.append(f"[{dep} decision] {k}: {v['value']} — {v.get('reason', '')}")
        return "\n".join(context_parts)


def quick_flow(feature: str):
    """Demo: szybki test przepływu."""
    wf = WorkflowState(feature)
    print(f"=== Workflow: {feature} ===")
    print()

    for phase in WorkflowState.PHASES:
        if wf.can_start(phase):
            wf.phase_start(phase)
            print(f"  ▶ {phase} — START")
            wf.phase_complete(phase, verdict="pass",
                              agent=f"opencode-{phase.split('-')[1] if '-' in phase else phase}")
            print(f"  ✅ {phase} — PASS")
        else:
            print(f"  ⏳ {phase} — waiting for dependencies")

    print()
    print(wf.summary())
    return wf


if __name__ == "__main__":
    import sys
    feature = sys.argv[1] if len(sys.argv) > 1 else "demo-feature"
    quick_flow(feature)
