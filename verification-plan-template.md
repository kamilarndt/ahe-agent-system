---
description: >-
  Verification Plan template for AHE agents. Each agent MUST include a
  Verification Criteria section that defines what external evidence is required
  before the phase can be considered "passed." This bridges the gap between
  Pi self-assertion and objective verification.
usage: |
  Copy this file into any agent definition (opencode-*.md or pi-*.md) under
  a ## Verification Plan header. Fill in the YAML frontmatter-esque section
  with your phase's specific checks and evidence files.

  The orchestrator reads `verification_criteria` and `required_evidence` from
  WorkflowState.VERIFICATION_CRITERIA at context-generation time and passes
  them to the agent. The agent MUST produce the evidence files listed here.
---

## Verification Plan

### Phase Identity
- **Workflow phase:** `XX-<phase-name>`
- **Agent:** `<agent-name>`
- **Required evidence files in `.hermes/workflow/<feature>/evidence/<phase>/`:**

### Pre-Flight Checklist (before agent starts work)
> Every item below must be confirmed by reading artifacts, NOT by assuming.

| # | Check | How to Verify | Source |
|---|-------|---------------|--------|
| 1 | Dependency artifacts exist | Read state.json → check `phases.<dep>.status == "completed"` | `.hermes/workflow/<feature>/state.json` |
| 2 | Previous phase evidence exists | Check evidence directory for prior phase evidence files | `.hermes/workflow/<feature>/evidence/<dep>/` |
| 3 | Agent has correct permissions | Read agent definition → check `permission.edit` | This file's frontmatter |
| 4 | No blockers from prior phases | Check for `blockers.md` in prior phase directories | `.hermes/workflow/<feature>/<dep>/blockers.md` |

### Verification Criteria (what must be proven)
> Each criterion is an objective check with external evidence.
> The agent MUST produce each evidence file listed.

| # | Check | Failure Mode | Required Evidence File | How to Generate |
|---|-------|--------------|------------------------|-----------------|
| 1 | `<check_name>` | `<what happens if it fails>` | `<filename.txt>` | `<command or tool>` |
| 2 | `<check_name>` | `<what happens if it fails>` | `<filename.txt>` | `<command or tool>` |

### Evidence Format
Every evidence file MUST be:
1. **Plain text or markdown** — machine-readable, human-readable
2. **Timestamps** at the top — `# Generated: <ISO timestamp>`
3. **Exit code** at the bottom — `# Exit: 0` for PASS, `# Exit: 1` for FAIL
4. **Verbatim output** from the tool — no paraphrasing or truncation

Example evidence file:
```
# Generated: 2026-07-01T12:00:00Z
# Tool: pytest -x --tb=short
# Phase: 03-build

[... actual test output ...]

# Passed: 42
# Failed: 0
# Exit: 0
```

### Post-Phase Verification (orchestrator runs this)
After the agent completes, the orchestrator calls:

```python
wf.record_verification(phase, check_name, passed=True,
                       evidence="path/to/evidence.txt",
                       detail="42 tests passed, 0 failed")
```

The orchestrator's `cmd_complete` warns if expected evidence files are missing.

### Gate Decision Logic
```
ALL checks passed AND all evidence files exist
  → phase verdict: "pass" → proceed to next phase

ANY check failed OR evidence file missing
  → phase verdict: "fail" → log warning, proceed anyway (gate agents catch it)
  → OR if strict_mode=true: BLOCK immediately

CRITICAL security/blocker check failed
  → phase verdict: "blocked" → STOP pipeline, return to builder
```

### Template: Per-Agent Verification Matrix
Copy the table below into each agent's definition, replacing placeholders:

```yaml
# Verification Criteria (ETCLOVG)
verification:
  phase: "XX-<name>"
  pre_flight:
    - "Dependency artifacts exist in .hermes/workflow/<feature>/<dep>/"
    - "No blockers.md found in prior phases"
  checks:
    - name: "<check_name>"
      evidence_required: "<filename.txt>"
      generate_with: "<shell command to produce evidence>"
      fail_if: "<condition that means the check failed>"
  gate:
    all_pass: "proceed"
    any_fail: "warn_and_proceed"  # or "block"
    critical_fail: "block"
```
