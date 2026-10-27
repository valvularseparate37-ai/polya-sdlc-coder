---
goal: Repository Architecture and Clean Architecture Seams Documentation
date_created: 2026-10-27
last_updated: 2026-10-27
status: 'Active'
tags: ["architecture", "clean-architecture", "polya-topography", "system-map"]
---
<!-- markdownlint-disable -->

# Repository Architecture Documentation

![Status: Active](https://img.shields.io/badge/status-active-brightgreen)

This document serves as the canonical architectural map of the repository. It outlines the system topology, Clean Architecture seams, directory responsibilities, and module constraints to assist developers and AI agents in understanding how the project is organized and where future work should live.

---

## 1. Executive Overview & Domain Context

- **System Purpose:** This repository is a Pólya SDLC orchestration and skill framework for AI coding agents. It provides a structured workflow across discovery, specification, planning, coding, review, and documentation, using Clean Architecture and George Pólya problem-solving heuristics.
- **Domain Ubiquitous Language:** The repository's canonical domain language is centered on SDLC phases, architectural seams, tracer bullets, and system governance. Key concepts include: discovery, PRD, spec, plan, review, audit, and Clean Architecture layers.
- **Target Environments:** This repository is primarily a documentation and workflow scaffold used by AI coding agents and developers; it is not a production application runtime. It is designed for multi-platform AI tools such as GitHub Copilot and similar agent environments.

---

## 2. High-Level Tech Stack & Tooling

| Dimension | Technologies / Tools | Configuration Files |
| :--- | :--- | :--- |
| **Primary Language(s)** | Markdown, shell scripts, JavaScript/Node examples, general project tooling | `README.md`, `install.sh`, `install.ps1`, `AGENTS.md` |
| **Core Frameworks** | GitHub Copilot / agent orchestration, Pólya SDLC skill architecture | `.agents/`, `skills/` |
| **Persistence / Storage** | Repository-backed markdown artifacts; no application database discovered | `docs/`, `docs/spec/`, `docs/plan/` |
| **Build & Packaging** | Static documentation site and installation scripts | `index.html`, `install.sh`, `install.ps1` |
| **Testing Harnesses** | Example Node test files in the reference implementation area | `examples/secure-login-service/login-service.test.js` |
| **Linter & Formatters** | Markdown lint conventions and project documentation standards | `.agents/standards/`, `AGENTS.md` |

---

## 3. Pólya's Topological Map ("Draw a Figure")

### 3.1 High-Level System Container Topology
```text
┌──────────────────────────────────────────────────────────────────────┐
│                    AI Agent / Developer Runtime                       │
│        [GitHub Copilot / Cursor / Claude / Other agent platform]      │
└───────────────────────────┬──────────────────────────────────────────┘
                            │ natural-language invocation / slash commands
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                          Polya SDLC Orchestrator                     │
│          AGENTS.md + .agents/rules/PolyaOrchestrator.md              │
└───────────────────────────┬──────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                        Skill Execution Layer                         │
│   to-ask-help • to-explore • to-prd • to-spec • to-plan • to-code   │
│   to-review • to-docs • to-map • to-memory • to-init                 │
└───────────────────────────┬──────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Documentation & Artifact Layer                    │
│    docs/discovery/ • docs/prd/ • docs/spec/ • docs/plan/ • docs/adr/ │
│    docs/reviews/ • docs/audit/ • docs/how-to/ • docs/reference/      │
└───────────────────────────┬──────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    Downstream Implementation Realms                   │
│     (not present in this repo; app code is expected in target project) │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 4. Clean Architecture Seams & Component Boundaries

*Dependency Rule: Source code dependencies MUST point inwards toward high-level business policies.*

```text
Entities (Domain Layer)
   └── Business concepts, domain rules, value objects, invariants
Use Cases (Application Layer)
   └── Workflow orchestration, use-case logic, planning & execution rules
Interface Adapters (Controllers, Gateways, Presenters)
   └── Agent commands, adapters, UI/documentation rendering
Frameworks & Drivers (DB, Web Server, UI Runtimes)
   └── GitHub, file system, scaffolding tools, execution environment
```

### 4.1 Layer Breakdown
- **Domain Layer (`skills/` conceptual domain + AGENTS governance):**
  - Contains the concepts of discovery, specification, planning, implementation, review, and documentation.
  - Invariant: No direct runtime dependency on external hosting or app frameworks.
- **Application Layer (`.agents/rules/` + `skills/` orchestration):**
  - Contains workflow logic, command routing, and phase-specific execution contracts.
  - Invariant: Orchestrates the agent process without coupling to any specific target application implementation.
- **Interface Adapters (`README.md`, `index.html`, docs templates):**
  - Contains user-facing guidance, web docs, install flows, and artifact generation wrappers.
  - Invariant: Converts raw project intent and templates into human-friendly artifacts and scaffold outputs.
- **Frameworks & Drivers (`install.sh`, `install.ps1`, GitHub repo, toolchain):**
  - Contains the execution environment, repository scaffolding, and platform-install hooks.
  - Invariant: This layer exists to support orchestration and delivery, not to own business logic.

---

## 5. Data Flow Lifecycle & Core Invariants

### 5.1 Standard Request/Execution Flow
```text
1. User / Agent Prompt
   └── Routed to a skill (e.g., /to-spec, /to-plan, /to-map)
2. Agent Instructions & Rules
   └── Validate phase and read project standards
3. Skill Workflow
   └── Performs discovery, synthesis, or artifact generation
4. Output Artifact
   └── Creates or updates docs/spec, docs/plan, docs/adr, or docs/ARCHITECTURE.md
5. Human Gate / Approval
   └── Explicit confirmation required before implementation work proceeds
```

### 5.2 Architectural Invariants
- **INV-001 (Boundary Isolation):** Repository rules and workflow logic are intentionally separated from target application code; the project is a reusable SDLC framework rather than a domain runtime.
- **INV-002 (Dependency Inversion):** Skill logic depends on rule files and templates, not on hidden implementation magic. The use of `.agents` as the system control layer preserves clean separation.
- **INV-003 (Symmetry & Lifecycle):** Each phase produces a single canonical artifact (`docs/spec/{slug}-spec.md`, `docs/plan/{slug}-plan.md`, etc.) to keep the workflow traceable and non-duplicative.

---

## 6. Directory Tree Map & Responsibilities

### 6.1 Repository Topography
```text
[Project Root]
├── .agents/                # AI agent configuration, rules, instructions, skills, standards
├── .codex/                 # Platform-specific config for Codex-oriented workflows
├── .impeccable/            # Additional tooling or guardrail configuration
├── docs/                   # Architecture maps, ADRs, specs, plans, reviews, audit files
│   ├── adr/                # Architecture Decision Records
│   ├── spec/               # Canonical spec documents
│   ├── plan/               # Canonical plan documents
│   ├── audit/              # Clarification and audit reports
│   ├── reviews/            # Review reports
│   └── ARCHITECTURE.md     # Canonical architecture map
├── skills/                 # Public skill catalog for the SDLC workflow
│   ├── to-spec/            # Specification skill
│   ├── to-plan/            # Planning skill
│   └── ...                 # More SDLC skills
├── examples/               # Reference code examples for the SDLC concepts
│   └── secure-login-service/ # Sample secure login reference implementation
├── AGENTS.md               # Root governance and operational instructions
├── CONTEXT.md              # Domain glossary and canonical terminology
├── README.md               # Project README and onboarding guide
├── install.sh              # Unix installer
├── install.ps1             # PowerShell installer
├── index.html              # Static docs landing page
├── LICENSE                 # MIT license
└── ...                     # Media assets and docs site files
```

### 6.2 Directory Responsibilities Matrix
| Directory / Module | Primary Purpose | Clean Architecture Layer | Allowed Dependencies | Rules & Constraints |
| :--- | :--- | :--- | :--- | :--- |
| `.agents/` | Agent runtime rules, prompts, templates, standards | Frameworks & Drivers | All inner layers | Must remain declarative and instruction-first |
| `skills/` | SDLC phase skills and task orchestration | Application / Interface Adapters | `.agents/`, `docs/` | No production app code ownership |
| `docs/` | Canonical artifacts and architecture records | Interface Adapters / Documentation | All layers | Single file per artifact policy enforced |
| `examples/` | Reference implementation examples | Use Cases / Domain examples | Example-only libraries | Can contain demonstrative code, not core repo code |
| `AGENTS.md` | Root project constitution | Administrative governance | All layers | Highest-level rules and human-facing guidance |

---

## 7. Key Configuration Files & Entry Points

- **Installation / bootstrap:** `install.sh`, `install.ps1` — bootstrap Pólya SDLC into a target project.
- **Project constitution:** `AGENTS.md` — root behavioral contract for all agents.
- **Canonical vocabulary:** `CONTEXT.md` — glossary and domain language.
- **Primary skill catalog:** `skills/` — contains the active SDLC skill modules.
- **Static docs shell:** `index.html` — web documentation entry point.

---

## 8. Mechanical Quality Constraints, Verification Commands & Ratchets

*Inspired by Constraint-Driven Development: Quality bars are enforced mechanically via speed-tiered commands, non-regressing ratchets, and floor-guard anti-tampering rules.*

### 8.1 The Immutable Quality Floor (Zero Setup, Always Enforced)
- **Zero Suppressions:** No `@ts-ignore`, `@ts-nocheck`, `@ts-expect-error`, `eslint-disable`, `# noqa`, `# type: ignore`, `istanbul ignore`, `nosemgrep`, `Stryker disable`, or `gitleaks:allow`.
- **Zero Test Weakening:** No `.skip`, `xit`, `pytest.mark.skip`, `@Disabled`, deleted failing tests, or stripped assertions.
- **Zero Unimplemented Stubs:** No `throw new Error("Not implemented")`, `TODO` placeholders in completed slices, or silent empty `catch {}` blocks.
- **Zero Secrets in VCS:** Every commit must pass secret scanning (`gitleaks detect --redact --no-banner`).
- **Zero Bar-Lowering:** Agents MUST NEVER lower numeric thresholds, coverage floors, or ratchets in this file or in tool configurations.

### 8.2 Speed-Tiered Verification Commands (`check:fast`, `check:task`, `check:full`)
| Tier | Target Latency | When Executed | Exact CLI Command(s) |
| :--- | :--- | :--- | :--- |
| **`check:fast`** | `< 5s` | Every file edit (Micro level) | `node --test examples/secure-login-service/login-service.test.js` |
| **`check:task`** | `< 90s` | End of each Vertical Tracer Bullet | `node --test examples/secure-login-service/login-service.test.js` |
| **`check:full`** | `< 5m` | Macro Phase Checkpoint / `/to-review` / CI | `node --test` for the repository’s relevant test set |

### 8.3 Non-Regressing Quality Ratchets (Measure & Hold)
*For this repository, the main measurable quality bar is test execution and artifact integrity rather than a large application runtime.*

| Metric / Dimension | Current Ratchet Floor | Required Direction | Checked By |
| :--- | :--- | :--- | :--- |
| **Reference Test Execution** | `Pass` | Must remain passing (`>= Floor`) | `node --test ...` |
| **Artifact Integrity** | `No shadow copies` | Must remain consistent (`Single file per phase`) | repository inspection |
| **Documentation Quality** | `No broken template conventions` | Must remain consistent | markdown lint + manual review |

### 8.4 Approved Rule Exceptions (Time-Bounded)
| ID | Rule / Check Bypassed | File Path & Line | Technical Rationale | Approved By | Expires On |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `EX-001` | `None` | `N/A` | `No active exceptions` | `N/A` | `N/A` |

---

## 9. Architectural Health & Known Seams

- **Primary Seams:**
  - command routing and phase orchestration via `AGENTS.md` and `.agents/`
  - skill execution via `skills/`
  - document artifact generation in `docs/spec/`, `docs/plan/`, `docs/adr/`, and `docs/audit/`
  - installation and bootstrap flows via `install.sh` and `install.ps1`
- **Technical Debt / Hotspots:**
  - the repository is primarily an AI workflow framework, so application-business seams are intentionally absent; any real app implementation must live in a downstream project or example directory.
  - the architecture prioritizes governance and process consistency, meaning it is intentionally more document-driven than runtime-driven.
- **Recent Architecture Decisions:**
  - The repository uses single-file artifact generation and strict phase separation to prevent duplicate or shadow specs and plans.
  - The example `examples/secure-login-service/` demonstrates one clean, isolated security implementation pattern without contaminating the core framework.

---
