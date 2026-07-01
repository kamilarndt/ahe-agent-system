# Universal AHE Harness Recipe

Jak wrzucić AHE do dowolnego projektu w 5 minut.

## Szybki start

```bash
cd /path/to/your/project
bash <(curl -fsSL https://raw.githubusercontent.com/kamilarndt/ahe-agent-system/main/ahe-init.sh)
just pipeline "Add user authentication"
```

To wszystko. Masz harness z 4 agentami:
1. **spec** — rozbija task na kroki
2. **builder** — implementuje z TDD
3. **reviewer** — robi 5-osiowy review
4. **pi-quality-gate** — wydaje verdict APPROVE/BLOCK

---

## Ręczna instalacja (krok po kroku)

### Krok 1: Struktura katalogów

```bash
mkdir -p agents/opencode agents/pi .ahe/logs .ahe/cache .spec
```

### Krok 2: Agent definitions

Skopiuj pliki agentów z repozytorium:

```bash
# Minimalny zestaw (4 agentów)
for agent in opencode-spec opencode-builder opencode-reviewer opencode-ship; do
  curl -fsSL "https://raw.githubusercontent.com/kamilarndt/ahe-agent-system/main/opencode/${agent}.md" \
    -o "agents/opencode/${agent}.md"
done

curl -fsSL "https://raw.githubusercontent.com/kamilarndt/ahe-agent-system/main/pi/pi-quality-gate.md" \
  -o "agents/pi/pi-quality-gate.md"
```

### Krok 3: harness.yaml

```yaml
harness_version: "1.0.0"
project_name: "my-project"

models:
  default: "groq/qwen/qwen3-32b"
  cheap: "groq/qwen/qwen3.6-27b"
  quality: "nvidia/deepseek-ai/deepseek-v4-pro"

agents:
  opencode-spec: true
  opencode-builder: true
  opencode-reviewer: true
  pi-quality-gate: true

topology:
  phases:
    - name: "spec"
      agent: "opencode-spec"
    - name: "build"
      agent: "opencode-builder"
    - name: "review"
      agent: "opencode-reviewer"
    - name: "verify"
      agent: "pi-quality-gate"
      gate: true
```

### Krok 4: justfile

```makefile
default:
  @just --list

pipeline task="":
  opencode run --agent opencode-spec "{{task}}"
  opencode run --agent opencode-builder "Implement the spec"
  opencode run --agent opencode-reviewer "Review the implementation"
  opencode run --agent pi-quality-gate "Gate check"

run agent prompt:
  opencode run --agent opencode-{{agent}} "{{prompt}}"

gate:
  opencode run --agent pi-quality-gate \
    "Read all recent changes. Produce <fusion-verdict> with APPROVE | BLOCK."
```

### Krok 5: Uruchom

```bash
just pipeline "Add login with Google OAuth"
```

---

## Rozszerzanie harnessa

### Dodaj agenta PM (discover → strategy → PRD)

```yaml
agents:
  opencode-pm-discover: true
  opencode-pm-strategy: true
  opencode-pm-prd: true
  pi-pm-prd-review: true
```

```bash
curl -fsSL "https://raw.githubusercontent.com/kamilarndt/ahe-agent-system/main/opencode/opencode-pm-discover.md" \
  -o "agents/opencode/opencode-pm-discover.md"
# ... powtórz dla pozostałych PM agentów
```

### Dodaj QA testing (Playwright)

```yaml
agents:
  opencode-qa-runner: true
  opencode-qa-viewer: true
  pi-qa-validator: true
```

```bash
# Instaluj Playwright
npx playwright install --with-deps chromium
# Pobierz agentów
curl -fsSL "https://raw.githubusercontent.com/kamilarndt/ahe-agent-system/main/opencode/opencode-qa-runner.md" \
  -o "agents/opencode/opencode-qa-runner.md"
# Stwórz pierwszy story
mkdir -p .qa/stories
cat > .qa/stories/homepage.md << 'EOF'
# Story: Homepage loads

## URL
http://localhost:3000

## Steps
1. Navigate to the URL
2. Verify the main heading is visible
3. Check the sign-in button exists

## Expected
- Page loads without errors
- Main content area is displayed
EOF
```

### Dodaj security audit

```yaml
agents:
  pi-security: true
  pi-observability: true
```

---

## Topologie (gotowe przepływy)

| Topologia | Agents | Zastosowanie |
|-----------|--------|--------------|
| **spec→build→review→verify** | 4 ENG | Podstawowy pipeline developerski |
| **discover→strategy→prd→review→spec→build→verify→ship** | 8 ENG+PM | Full-stack PM → Engineering |
| **builder→quality-gate** | 2 ENG | Quick bugfix |
| **security→test-cov→obs→quality-gate** | 4 Pi | Pre-release audit |
| **qa-runner→qa-validator** | 2 QA | Browser testing |

---

## Wzór: Użycie w CI/CD

```yaml
# .github/workflows/ahe.yml
name: AHE QA
on: [pull_request]
jobs:
  qa:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm install -g opencode-ai
      - run: bash <(curl -fsSL https://raw.githubusercontent.com/kamilarndt/ahe-agent-system/main/ahe-init.sh)
      - run: just pipeline "Verify PR #{{ github.event.number }}"
```

---

## Pliki w template/

```
template/
├── harness.yaml          ← konfiguracja (wypełnij zmienne)
├── team-config.json      ← registry agentów
├── justfile              ← task runner
├── opencode/             ← agent definitions (kopiuj z /root/.hermes/agents/opencode/)
└── pi/                   ← pi agent definitions (kopiuj z /root/.hermes/agents/pi/)
```

## Zasada

> **Swap the brain, keep the body.**
> Model zmienisz w 1 linię w `harness.yaml`.
> Harness działa tak samo z każdym modelem.
