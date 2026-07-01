# ──────────────────────────────────────────────
# AHE — QA & Testing Justfile
# Reusability layer: run browser tests, view results
# ──────────────────────────────────────────────

# Default: show available commands
default:
  @just --list

# QA test stories directory
stories_dir := ".qa/stories"
screenshots_dir := ".qa/screenshots/{{run_id or "latest"}}"

# List all available QA stories
list-stories:
  @echo "=== QA Stories ==="
  @ls {{stories_dir}}/*.md 2>/dev/null | xargs -I{} basename {} .md || echo "(no stories found)"

# QA: run all browser tests with Playwright
qa-run story="*":
  @echo "Running QA: {{story}}"
  @mkdir -p .qa/logs .qa/screenshots/$(date +%s)
  @npx playwright install --with-deps chromium 2>/dev/null || true
  @echo "Starting opencode-qa-runner..."
  opencode run --agent opencode-qa-runner \
    "Run user stories matching '{{story}}' from {{stories_dir}}/. Report to .qa/reports/"

# QA: validate test results from latest run
qa-validate:
  @echo "Validating QA results..."
  opencode run --agent pi-qa-validator \
    "Read the latest report from .qa/reports/ and validate screenshots + logs."

# QA: full cycle — discover, run, validate
qa-full story="*":
  just qa-run {{story}}
  just qa-validate

# QA: open screenshots from latest run
qa-screenshots:
  @open {{screenshots_dir}} 2>/dev/null || echo "No screenshots found in {{screenshots_dir}}"

# QA: write a new story (opens template)
qa-new-story name:
  @cp {{stories_dir}}/TEMPLATE.md {{stories_dir}}/{{name}}.md
  @echo "Created {{stories_dir}}/{{name}}.md — edit with your test steps"

# Test: verify Playwright CLI is installed
check:
  @echo "=== AHE QA Checks ==="
  @npx playwright --version 2>/dev/null && echo "✓ Playwright installed" || echo "✗ Install: npx playwright install chromium"
  @which just 2>/dev/null && echo "✓ just installed" || echo "✗ just missing"
  @ls {{stories_dir}}/*.md 2>/dev/null | wc -l | xargs -I{} echo "✓ {} story files found" || echo "✗ No stories in {{stories_dir}}/"
