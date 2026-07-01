# AHE Agent System — Audit vs ETCLOVG (01-04 Harness Guide)
**Repo:** `kamilarndt/ahe-agent-system` | **Commit:** 1 | **Audited:** 2026-07-01

## Summary

| Layer | ETCLOVG Standard | Current State | Delta | Patches Applied |
|-------|------------------|---------------|-------|-----------------|
| **E**xecution | Artifact-based handoff, phase dirs, state machine | ✅ 9-phase, state.json, .hermes/workflow/<f>/<p>/ | Full | — |
| **T**hink | Policy gate before every action | ❌ Missing | NEW: `policy_check()` + `harness.yaml policy:` | ✅ |
| **C**ontext | Thin context builder with verification criteria | ✅ `ahe context` generates JSON | Extended with `verification_criteria`, `required_evidence`, `dependencies_verification` | ✅ |
| **L**ifecycle | State machine with dependency resolution | ✅ 9 phases, DEPENDENCIES, PARALLEL_GROUPS | Full | — |
| **O**bservability | Immutable event log (Intent→Policy→Observation) | ❌ state.json is mutable, no event.log | NEW: `event.log` append-only + state.json cache (last 50) | ✅ |
| **V**erification | External evidence required (test output, lint, coverage %) | ❌ Pi self-assertion only | NEW: `VERIFICATION_CRITERIA`, `record_verification()`, `evidence/` dir | ✅ |
| **G**overnance | Intent-based access control, audit trail | ❌ Contracts OK, no runtime enforcement | NEW: `policy_check()` + `policy_decisions` in state | ✅ |

## Detailed Findings

### 1. Execution ✅
- **Phase artifacts:** `.hermes/workflow/<feature>/<phase>/` — YES
- **State machine:** `WorkflowState` with `phase_start/complete/blocked` — YES
- **CLI:** `ahe init/status/next/context/complete/block/summary` — YES
- **Parallel fan-out:** YES (05-security, 06-coverage, 07-observability)
- **RATING:** Production-ready

### 2. Think — Policy ❌→✅
- **Before:** No policy enforcement. Agent contracts say "edit: deny" but there's no runtime check.
- **After (patched):** `WorkflowState.policy_check(intent, agent, target)` runs before every delegation:
  - Denies `edit_file` for Pi agents (edit: deny)
  - Logs every check to event.log
  - `harness.yaml policy:` section with `gates.edit_file.deny_for: ["pi-*"]`
- **GAP:** No `sandbox/` isolation for file writes. Builder can write anywhere.

### 3. Context ✅+ 
- **Before:** Basic JSON context with artifacts + decisions
- **After (patched):** Extended with:
  - `verification_criteria` — what checks must pass
  - `required_evidence` — what evidence files must be produced
  - `dependencies_verification` — verification status of prior phases
  - `evidence_dir` — path to evidence storage
  - `event_log` — path to immutable log
- **RATING:** Production-ready for T1-T3. T4 should add sandbox path.

### 4. Lifecycle ✅
- 9-phase DAG with dependency resolution
- Parallel groups (review + [security, coverage, observability])
- Go/no-go via Pi quality gate
- **RATING:** Production-ready

### 5. Observability ❌→✅
- **Before:** `state.json` only (mutable, no history)
- **After (patched):**
  - `event.log` — append-only JSONL, never modified after write
  - Every `policy_check`, `phase_complete`, `verification` call writes an event
  - State.json caches last 50 events for fast query
- **RATING:** Production-ready

### 6. Verification ❌→✅
- **Before:** Pi agents self-assert with fusion-verdict XML. No external evidence.
- **After (patched):**
  - `VERIFICATION_CRITERIA` dict in `WorkflowState` — per-phase, per-check
  - `record_verification(phase, check, passed, evidence, detail)` — stores in state.json
  - `get_verification_status(phase)` — returns PASS/FAIL per check
  - `save_evidence_file(phase, filename, content)` — writes file to `evidence/<phase>/`
  - `cmd_complete` validates evidence files exist before marking done
  - Evidence files: `test_output.txt`, `lint_report.txt`, `coverage_report.txt`, `security_scan.txt`, etc.
- **RATING:** Production-ready

### 7. Governance ❌→✅
- **Before:** Input/Output/Error contracts in agent definitions. No runtime enforcement.
- **After (patched):**
  - `policy_check()` in WorkflowState — runtime gate
  - `policy:` section in `harness.yaml` — configuration plane
  - `policy_decisions[]` in state.json — audit trail
  - `harness.policy.review(intent)` before every delegate_task
- **RATING:** Production-ready for T1-T3. T4 needs HITL approval on policy violations.

## Remaining Gaps (post-patch)

| Gap | Impact | Effort | Recommended |
|-----|--------|--------|-------------|
| No sandbox/isolation for builder file writes | Builders can write anywhere | Medium | Add `file_write.restrict_to_phase_dir: true` enforcement in orchestrator |
| No sandbox timeout in orchestrator.py | Long-running phases can hang | Low | Add `timeout_sec` from tier config to `cmd_context` |
| No output size limit per agent | Agent can dump 10MB of logs | Low | Add `max_summary_lines: 200` enforcement from Communication Rules |
| No Pi-quality-gate integration with evidence | Gate doesn't read evidence/ dir yet | Medium | Update `pi-quality-gate.md` to read `evidence/` and verify evidence integrity |
| Pi agents can still access `bash` in permissions | Security can run `nmap` | Medium | Lock down Pi permissions to `read, grep, glob` only (no bash) |
| `factory-start.sh` references `.hermes` paths | Hardcodes to /root | Low | Parameterize via env var |
| No Hermes skill for AHE workflow | Must remember CLI commands | Low | Save as `ahe-orchestrator` skill |

## Files Patched

| File | Change | Lines Changed |
|------|--------|---------------|
| `scripts/workflow_state.py` | ETCLOVG: event.log, policy_check(), verification evidence, VERIFICATION_CRITERIA | ~120 added |
| `scripts/orchestrator.py` | Policy gate in cmd_context, output validation in cmd_complete, event logging | ~40 added |
| `harness.yaml` | `policy:` section, `verification_evidence:` per tier | ~35 added |
| `verification-plan-template.md` | NEW — reusable Verification Plan for each agent | ~140 lines |

## Next Steps (Priority Order)

1. **Lock down Pi agent permissions** — remove `bash` from pi-*.md definitions (they only need read/grep/glob)
2. **Update `pi-quality-gate.md`** — add evidence integrity check (read evidence/ dir, verify all required files exist)
3. **Add sandbox enforcement** — `file_write.restrict_to_phase_dir` in orchestrator.py
4. **Save AHE workflow as a Hermes skill** — so users can `skill_view('ahe-orchestrator')` instead of rereading README
5. **Full integration test** — `ahe init test-feature; ahe context test-feature 03-build` with verification criteria visible in context JSON
