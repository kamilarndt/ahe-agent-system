# ──────────────────────────────────────────────
# AHE — QA & Testing Justfile
# Reusability layer: run browser tests, view results
# ──────────────────────────────────────────────

stories_dir := ".qa/stories"

# Default: show available commands
default:
  @just --list

# List all available QA stories
list-stories:
  @echo "=== QA Stories ==="
  @ls {{stories_dir}}/*.md 2>/dev/null | xargs -I{} basename {} .md || echo "(no stories found)"

# QA: run all browser tests with Playwright
qa-run story="*":
  @echo "Running QA: {{story}}"
  @mkdir -p .qa/logs .qa/screenshots
  @npx playwright install --with-deps chromium 2>/dev/null || true
  @echo "Starting opencode-qa-runner..."
  opencode run --agent opencode-qa-runner \
    "Run user stories matching '{{story}}' from {{stories_dir}}/. Report to .qa/reports/"

# QA: validate test results from latest run
qa-validate:
  @echo "Validating QA results..."
  opencode run --agent pi-qa-validator \
    "Read the latest report from .qa/reports/ and validate screenshots + logs."

# QA: full cycle
qa-full story="*":
  just qa-run {{story}}
  just qa-validate

# QA: write a new user story
qa-new-story name:
  @cp {{stories_dir}}/TEMPLATE.md {{stories_dir}}/{{name}}.md
  @echo "Created {{stories_dir}}/{{name}}.md"

# Verify QA tools are installed
check:
  @echo "=== AHE QA Checks ==="
  @npx playwright --version 2>/dev/null && echo "Pass: Playwright" || echo "Fail: npx playwright install chromium"
  @ls {{stories_dir}}/*.md 2>/dev/null | wc -l | xargs -I{} echo "Pass: {} stories" || echo "Info: no stories"
