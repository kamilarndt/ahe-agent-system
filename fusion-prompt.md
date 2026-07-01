# Fusion Prompt — Pi Verifier Gate Protocol

Structured verification protocol for all Pi agents. Every Pi agent MUST
produce its output as **XML inside a markdown code block**, with a clear
verdict, evidence summary, and optional blocking reason.

## Protocol

### 1. Pi Agent Receives Task

Pi agent gets:
- The code/artifact to verify (file paths + content)
- The verification criteria (from its agent definition)
- This protocol

### 2. Pi Agent Produces Structured Output

```xml
<fusion-verdict>
  <verdict>APPROVE | REJECT | BLOCK</verdict>
  <gate>security | test-coverage | quality | observability | prd-review | strategy | market-fit | discovery-audit</gate>
  <confidence>high | medium | low</confidence>
  <evidence>
    <item file="path/to/file.py:42" severity="critical|high|medium|low|info">
      Finding description with specific line references.
    </item>
    <item file="path/to/test.py:15" severity="info">
      Test coverage gap in edge case for empty input.
    </item>
  </evidence>
  <passed>3</passed>
  <failed>1</failed>
  <blocking_reason>If BLOCK: one-sentence explanation of what must be fixed.</blocking_reason>
  <recommendation>Specific, actionable next step for the builder agent.</recommendation>
</fusion-verdict>
```

### 3. Bias Toward Approval Rules

When Hermes receives the fusion verdict, apply these rules in order:

1. **Functional stability over style.** If code compiles, tests pass, and no
   data-loss/security issues exist, APPROVE. Subjective preferences (naming,
   formatting, "this could be cleaner") are suggestions, not blocks.

2. **Pedantic linter warnings are INFO, not BLOCKERS.** Linter warnings about
   line length, trailing whitespace, or unused imports are severity "info"
   unless they indicate a real bug.

3. **False positive filter.** If two Pi agents disagree (e.g., security says
   BLOCK but quality-gate says APPROVE), Hermes re-reviews the evidence.
   If the BLOCK is based on a false positive, dismiss it.

4. **The merge decision belongs to the orchestrator.** Pi agents recommend.
   Hermes decides. A Pi BLOCK means "I found a problem" — Hermes decides
   whether it's a real blocker.

### 4. Verdict Meanings

| Verdict | Meaning | Action |
|---------|---------|--------|
| APPROVE | No issues found, or only minor suggestions | Proceed to next phase |
| REJECT | Issues found that should be fixed but aren't blockers | Return to builder, iterate |
| BLOCK | Critical issue — security vuln, data loss, breaking change | STOP pipeline, report to user |

### 5. Example: Quality Gate Fusion Output

```xml
<fusion-verdict>
  <verdict>APPROVE</verdict>
  <gate>quality</gate>
  <confidence>high</confidence>
  <evidence>
    <item file="src/auth/login.ts:45" severity="info">
      Console.log left in — should be removed or replaced with logger.
    </item>
    <item file="src/auth/login.ts:67" severity="low">
      Error message is generic. Consider adding more context for debugging.
    </item>
  </evidence>
  <passed>5</passed>
  <failed>0</failed>
  <blocking_reason></blocking_reason>
  <recommendation>Address the console.log and error message in a follow-up PR.</recommendation>
</fusion-verdict>
```

### 6. Example: Security BLOCK

```xml
<fusion-verdict>
  <verdict>BLOCK</verdict>
  <gate>security</gate>
  <confidence>high</confidence>
  <evidence>
    <item file="src/api/users.ts:23" severity="critical">
      SQL query uses f-string interpolation with user input: `SELECT * FROM users WHERE id = '{user_input}'`.
      This is a SQL injection vulnerability. Use parameterized queries.
    </item>
  </evidence>
  <passed>3</passed>
  <failed>1</failed>
  <blocking_reason>SQL injection vulnerability in user lookup endpoint.</blocking_reason>
  <recommendation>Replace f-string with parameterized query: `SELECT * FROM users WHERE id = $1`</recommendation>
</fusion-verdict>
```

### 7. Example: PRD Review REJECT

```xml
<fusion-verdict>
  <verdict>REJECT</verdict>
  <gate>prd-review</gate>
  <confidence>medium</confidence>
  <evidence>
    <item file="PRD-auth.md" severity="high">
      Section 4 (Objective) missing measurable Key Results. "Improve authentication" is not an objective.
    </item>
    <item file="PRD-auth.md" severity="high">
      Section 5 (Market Segment) is empty. Target users not defined.
    </item>
  </evidence>
  <passed>6</passed>
  <failed>2</failed>
  <blocking_reason>PRD missing measurable objectives and target market definition.</blocking_reason>
  <recommendation>Add SMART Key Results to Section 4, define target segment in Section 5.</recommendation>
</fusion-verdict>
```

## Integration

This protocol is loaded automatically when any Pi agent is spawned.
The orchestrator (Hermes) parses the XML verdict and decides the next action:

```
Pi agent output
  │
  ▼
Parse <fusion-verdict> XML
  │
  ├── BLOCK  → STOP pipeline, report to user with blocking_reason
  ├── REJECT → Return to builder, attach recommendation
  └── APPROVE→ Proceed to next phase
                │
                └── Bias toward approval check
                    └── If linter-only issues → force APPROVE
