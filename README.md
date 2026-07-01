# Agent Harness Engineering — Specjalistyczni Agenci + Orchestration

Agent definitions bazowane na wzorcach z [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) —
produkcyjne persony dla **OpenCode** (implementacja) i **Pi Agent** (weryfikacja), z pełnym
systemem komunikacji między agentami.

## Architektura Komunikacji

```
┌──────────────────────────────────────────────────────────────────┐
│                     HERMES ORCHESTRATOR                           │
│       (delegate_task, artifact handoff, state machine)            │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐     ┌──────────┐     ┌───────────────────────┐    │
│  │ PHASE 1  │ ──▶ │ PHASE 2  │ ──▶ │  PHASE 3              │    │
│  │ spec     │     │ arch     │     │  build                 │    │
│  │ PRD.md   │     │ ADR.md   │     │  code + tests          │    │
│  └──────────┘     └──────────┘     └────────┬───────────────┘    │
│                                              │                    │
│                    ┌─────────────────────────┼────────────────┐   │
│                    │       PARALLEL FAN-OUT  │                │   │
│                    ▼                         ▼                ▼   │
│              ┌──────────┐            ┌──────────┐     ┌─────────┐│
│              │ PHASE 5  │            │ PHASE 6  │     │ PHASE 7 ││
│              │ security │            │ coverage │     │ observ. ││
│              └─────┬────┘            └─────┬────┘     └────┬────┘│
│                    └──────────┬────────────┘               │     │
│                               ▼                            │     │
│                         ┌──────────┐                       │     │
│                         │ PHASE 8  │ ◀─────────────────────┘     │
│                         │ fix      │                             │
│                         └────┬─────┘                             │
│                              ▼                                   │
│                         ┌──────────┐                             │
│                         │ PHASE 9  │                             │
│                         │ quality  │ → go/no-go                  │
│                         └──────────┘                             │
└──────────────────────────────────────────────────────────────────┘
```

### Jak komunikują się agenci?

| Mechanizm | Opis |
|-----------|------|
| **WorkflowState** (`state.json`) | Wspólna maszyna stanów — każdy agent czyta/zapisuje fazy, decyzje, artefakty |
| **Phase artifacts** (pliki) | Każda faza zapisuje pliki do `.hermes/workflow/<feature>/<phase>/` |
| **workflow_summary.md** | Każdy agent pisze summary (max 200 linii) dla następnych agentów |
| **delegate_task context** | Hermes przekazuje kontekst: fazę, zależności, ścieżki, decyzje |
| **blockers.md** | Gdy agent nie może skończyć — pisze blockers, reszta nie startuje |

### 9-fazowy workflow

| Faza | Agent | Tryb | Zależności | Output |
|------|-------|------|-----------|--------|
| **01-spec** | opencode-spec | primary | (first) | PRD.md, task-breakdown.md |
| **02-arch** | opencode-architect | primary | 01-spec | ADR, API contracts, data model |
| **03-build** | opencode-builder | primary | 01-spec, 02-arch | Code + tests + build-summary.md |
| **04-review** | opencode-reviewer | primary | 03-build | review-report.md (5-axis) |
| **05-security** | pi-security | subagent | 03-build | security-audit.md |
| **06-coverage** | pi-test-coverage | subagent | 03-build | coverage-gaps.md |
| **07-observability** | pi-observability | subagent | 03-build | observability-audit.md |
| **08-fix** | opencode-builder | primary | 04, 05, 06, 07 | fix-summary.md |
| **09-quality** | pi-quality-gate | subagent | 08-fix | quality-gate.md (go/no-go) |

### Równoległe grupy

Fazy 05, 06, 07 (security, coverage, observability) mogą lecieć **równolegle** —
Hermes używa `delegate_task(tasks=[...])` z batch mode.

## OpenCode Agenci (budują)

| Agent | Rola | Użyj gdy... |
|-------|------|-------------|
| **spec** | Spec-Driven Developer | Trzeba zdefiniować wymagania → PRD → task breakdown |
| **builder** | Incremental Builder | Implementacja z TDD, jedna warstwa na raz |
| **reviewer** | Senior Code Reviewer | 5-osiowy review przed merge |
| **architect** | Technical Architect | API contracts, ADR, modułowa architektura |
| **perf** | Web Performance Auditor | Core Web Vitals, Lighthouse, INP/LCP/CLS |
| **ship** | Release Engineer | CI/CD, git workflow, changelog, go/no-go |
| **migration** | Migration Specialist | Bezpieczne deprecacje, migracje schematów |

### Uruchomienie

```bash
# Z poziomu projektu:
cd /path/to/project

# Uruchom konkretnego agenta przez OpenCode:
opencode --agent spec "Chcę dodać uwierzytelnianie do aplikacji"
opencode --agent builder "Zaimplementuj rejestrację użytkownika"
opencode --agent reviewer "Zreviewuj ten PR"

# Lub przez orchestrator (zalecane dla pełnego workflow):
ahe-init user-auth           # Inicjalizuj workflow
ahe-next user-auth           # Zobacz co jest gotowe
ahe-status user-auth         # Sprawdź postęp
```

## Pi Agenci (weryfikują)

| Agent | Rola | Użyj gdy... |
|-------|------|-------------|
| **pi-security** | Security Auditor | OWASP audyt przed release |
| **pi-test-coverage** | Test Coverage Analyst | Analiza luk w testach |
| **pi-quality-gate** | Quality Gate | Finalne "czy możemy mergować?" |
| **pi-observability** | Observability Compliance | logging, metrics, tracing audit |

Wszyscy Pi Agenci mają `mode: subagent` + `edit: deny` — **nie piszą kodu**.
Ich output to raport → builder implementuje fixy.

## Orchestrator CLI

```bash
# Zainstaluj w projekcie
bash /root/.hermes/agents/install-workflow.sh /path/to/project

# Komendy
ahe init user-auth           # Inicjalizuj workflow dla feature
ahe status user-auth         # Pokaż postęp wszystkich faz
ahe next user-auth           # Pokaż następną gotową fazę
ahe context user-auth 03-build  # Wygeneruj kontekst dla delegate_task
ahe complete user-auth 03-build pass opencode-builder
ahe block user-auth 03-build "Missing database schema"
ahe summary user-auth        # Pełny summary (dla quality gate)
```

## Wzorzec: Użycie z Hermes (rekomendowane)

Najlepszy sposób na uruchomienie pełnego pipeline'u:

```python
# Krok 1: Zainicjalizuj workflow
# (w terminal: ahe init user-auth)

# Krok 2: Uruchom sekwencyjnie przez delegate_task
# Hermes generuje context przez ahe context <feature> <phase>

# Faza 1 - Spec
delegate_task(
    goal="Utwórz specyfikację dla uwierzytelniania użytkownika",
    context=ahe context user-auth 01-spec,
    toolsets=["terminal", "file"]
)

# Faza 2 - Architektura
delegate_task(
    goal="Zaprojektuj architekturę uwierzytelniania",
    context=ahe context user-auth 02-arch,
    toolsets=["terminal", "file"]
)

# Faza 3 - Builder
delegate_task(
    goal="Zaimplementuj uwierzytelnianie z TDD",
    context=ahe context user-auth 03-build,
    toolsets=["terminal", "file"]
)

# Fazy 5, 6, 7 - Równoległy fan-out Pi agentów
delegate_task(tasks=[
    {"goal": "Audyt bezpieczeństwa kodu"},
    {"goal": "Analiza pokrycia testami"},
    {"goal": "Audyt observability"},
])

# Faza 8 - Fix (dopiero po otrzymaniu wyników faz 5-7)
delegate_task(
    goal="Napraw znalezione problemy",
    context=ahe context user-auth 08-fix,
    toolsets=["terminal", "file"]
)

# Faza 9 - Quality Gate
delegate_task(
    goal="Finalna bramka jakości - czy można mergować?",
    context=ahe context user-auth 09-quality,
    toolsets=["terminal", "file"]
)
```

## Pliki komunikacji

Każdy agent ma teraz sekcję **Communication Protocol** z:

```
## Communication Protocol
### Input Contract   — co agent musi dostać (faza, artefakty, ścieżki)
### Output Contract  — co agent musi wyprodukować (pliki, summary, decyzje)
### Error Contract   — co zrobić gdy się zablokuje (blockers.md)
### Communication Rules — reguły: nie wołaj innych agentów, pisz summary, nie wychodź poza fazę
## Composition       — kiedy wywołać, od czego zależy, kto konsumuje
```

## Instalacja

```bash
# Instalacja w projekcie
bash /root/.hermes/agents/install-workflow.sh /path/to/project

# Sam test instalacji
bash /root/.hermes/agents/install-workflow.sh /tmp/test-install
```

## Struktura katalogów

```
project/
├── .hermes/
│   ├── workflow/
│   │   └── <feature>/
│   │       ├── 01-spec/          PRD.md, task-breakdown.md
│   │       ├── 02-arch/          ADR-*.md, openapi.yaml
│   │       ├── 03-build/         kod + testy + build-summary.md
│   │       ├── 04-review/        review-report.md
│   │       ├── 05-security/      security-audit.md
│   │       ├── 06-coverage/      coverage-gaps.md
│   │       ├── 07-observability/ observability-audit.md
│   │       ├── 08-fix/           fix-summary.md
│   │       ├── 09-quality/       quality-gate.md
│   │       └── state.json        (WorkflowState — machine-readable)
│   ├── scripts/
│   │   ├── workflow_state.py
│   │   └── orchestrator.py
│   └── agents/
│       ├── opencode-spec.md      (z Communication Protocol)
│       ├── opencode-builder.md
│       └── ...
├── agents/                       (skopiowane do projektu)
│   ├── opencode-spec.md
│   └── ...
└── docs/
    └── adr/                     (ADR generowane przez opencode-architect)
```

## Pliki źródłowe

| Ścieżka | Opis |
|---------|------|
| `/root/.hermes/agents/opencode/` | 7 OpenCode agentów z kontraktami |
| `/root/.hermes/agents/pi/` | 4 Pi agentów z kontraktami |
| `/root/.hermes/agents/scripts/workflow_state.py` | Menedżer stanu workflow |
| `/root/.hermes/agents/scripts/orchestrator.py` | Orchestrator CLI |
| `/root/.hermes/agents/install-workflow.sh` | Instalator |
| `/root/.hermes/agents/README.md` | Ta dokumentacja |
