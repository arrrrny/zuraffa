The zuraffa repository embeds a **spec-kit (Speckit) agent ecosystem** that drives specification-driven development (SDD) through natural-language commands. Two AI agent platforms consume the same skill definitions: **Zed** (via `.agents/skills/`) and **Kimi** (via `.kimi-code/skills/`). A third, specialized **GitHub Actions agent** lives at `.github/agents/surgical-pr-fix.agent.md` for CI failure triage. Together they form a layered system: templates define the artifact shape, scripts enforce invariant paths, and extension hooks inject domain-specific behavior at each lifecycle gate.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Agent Entry Points                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Zed Skills  │  │ Kimi Skills  │  │ GitHub Agent     │  │
│  │ .agents/     │  │ .kimi-code/  │  │ .github/agents/  │  │
│  │  (48 skills) │  │ (45 skills)  │  │ surgical-pr-fix  │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
└─────────┼──────────────────┼───────────────────┼────────────┘
          │                  │                   │
          ▼                  ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│               Speckit Core (.specify/)                       │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ Templates   │  │ Bash Scripts │  │ Extension Hooks  │  │
│  │ 5 templates │  │ 5 scripts    │  │ 7 extensions     │  │
│  └──────┬──────┘  └──────┬───────┘  └────────┬─────────┘  │
└─────────┼──────────────────┼───────────────────┼────────────┘
          │                  │                   │
          ▼                  ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                    Project State                             │
│  feature.json │ tdd-profile.md │ SPEC-STATS.md │ memory/    │
└─────────────────────────────────────────────────────────────┘
```

The system operates on a **four-phase lifecycle** driven by slash-commands: `/speckit-specify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-implement`. Each phase is a skill definition (a `SKILL.md` file) that declares pre-execution hooks, validation rules, and output templates. The bash scripts under `.specify/scripts/bash/` provide the invariant machinery — branch naming, path resolution, template composition — that keeps the lifecycle reproducible across agent platforms.

## Skill Inventory by Platform

The two agent platforms share a common skill vocabulary but differ in coverage:

| Platform | Skill Directory | Skill Count | Unique Skills |
|----------|----------------|-------------|---------------|
| Zed | `.agents/skills/` | 48 | `agent-context-update`, `md-doctor-*` (6), `workflow` |
| Kimi | `.kimi-code/skills/` | 45 | `worktrees-clean`, `worktrees-create`, `worktrees-list`, `worktrees-specify` |

The Kimi platform adds four **git worktree management** skills (`speckit-worktrees-*`) that the Zed platform lacks, while Zed retains the `speckit-workflow` skill for fully autonomous lifecycle execution. Both platforms implement the same core Speckit commands: `specify`, `plan`, `tasks`, `implement`, `clarify`, `constitution`, `converge`, `analyze`, `checklist`.

### Skill Categories

Skills cluster into functional families, each addressing a distinct concern:

| Category | Skills | Purpose |
|----------|--------|---------|
| **Lifecycle** | `specify`, `plan`, `tasks`, `implement`, `workflow` | Core SDD phase execution |
| **Clarification** | `clarify` | Reduce spec ambiguity before planning |
| **Constitution** | `constitution` | Establish project engineering principles |
| **Analysis** | `analyze`, `converge` | Assess codebase and converge on decisions |
| **Bug Workflow** | `bug-assess`, `bug-fetch`, `bug-fix`, `bug-issue`, `bug-pr`, `bug-test` | End-to-end bug triage → fix → PR |
| **Chore Workflow** | `chore-assess`, `chore-fetch`, `chore-implement`, `chore-issue`, `chore-pr` | Same pattern for non-bug changes |
| **Git Integration** | `git-commit`, `git-feature`, `git-initialize`, `git-remote`, `git-validate` | Branch management and commit automation |
| **GitHub Triage** | `gh-triage-feature`, `gh-triage-triage` | Issue labeling and assignment |
| **TDD Cycle** | `tdd-setup`, `tdd-plan`, `tdd-run`, `tdd-verify` | Red-green-refactor loop inside SDD |
| **GYM** | `gym-init`, `gym-warmup`, `gym-run`, `gym-gate`, `gym-drop` | Skill assessment exercises |
| **Spec Stats** | `spec-stats-open`, `spec-stats-runs`, `spec-stats-report`, `spec-stats-not-green` | Portfolio tracking and reporting |
| **MD Doctor** | `md-doctor-init`, `md-doctor-scan`, `md-doctor-drift`, `md-doctor-report`, `md-doctor-apply` | Markdown documentation drift detection |
| **Worktrees** (Kimi only) | `worktrees-create`, `worktrees-list`, `worktrees-clean`, `worktrees-specify` | Parallel feature branch management |

Sources: [.agents/skills/](.agents/skills), [.kimi-code/skills/](.kimi-code/skills)

## Extension Hook System

The `.specify/extensions.yml` file defines **seven extension families** that inject behavior at lifecycle gates:

| Extension | Hook Points | Key Behaviors |
|-----------|-------------|---------------|
| `git` | `before_specify`, `before_implement`, `after_tasks`, `after_implement`, `before_constitution`, `before_clarify` | Auto-create feature branch, auto-commit at phase boundaries |
| `tdd` | `before_implement` (mandatory), `after_tasks`, `after_implement` | Drive red-green-refactor before implementation; verify test discipline after |
| `gym` | `before_implement` | Block implementation until GYM gate is open |
| `bug` | (various) | Bug assessment → fix → test → issue → PR pipeline |
| `chore` | (various) | Same pipeline for non-bug changes |
| `gh-triage` | (various) | GitHub issue labeling and assignment |
| `spec-stats` | (various) | Portfolio tracking and dashboard generation |

The hook system supports **mandatory** (`optional: false`) and **optional** (`optional: true`) hooks. Mandatory hooks must execute and complete before the lifecycle proceeds; optional hooks are surfaced to the agent for decision. The `auto_execute_hooks: true` setting in `extensions.yml` controls whether optional hooks fire automatically.

Sources: [.specify/extensions.yml](.specify/extensions.yml#L1-L211)

## Template & Script Foundation

The lifecycle artifacts are shaped by five templates under `.specify/templates/`:

| Template | Purpose | Key Structure |
|----------|---------|---------------|
| `spec-template.md` | Feature specification | User stories with priority (P1/P2/P3), acceptance scenarios with `**Type**` markers |
| `plan-template.md` | Implementation plan | Technical context, constitution check, project structure, data model, dependencies |
| `tasks-template.md` | Task breakdown | Phase-gated tasks organized by user story, with `[P]` parallel markers |
| `checklist-template.md` | Quality review | Reviewer-owned checklist with `[x]` semantics for requirements-quality gates |
| `constitution-template.md` | Engineering principles | Core principles, governance, version tracking |

Five bash scripts provide invariant enforcement:

| Script | Responsibility |
|--------|---------------|
| `common.sh` | Repo root discovery, path resolution, template override stack, invoke separator parsing |
| `create-new-feature.sh` | Branch naming (stop-word filtering, 3-4 word extraction), feature directory creation, number assignment |
| `setup-plan.sh` | Plan template copying and path JSON emission |
| `setup-tasks.sh` | Tasks template resolution, available-docs enumeration |
| `check-prerequisites.sh` | Unified gate checking with `--json`, `--require-spec`, `--require-tasks`, `--include-tasks` flags |
| `resolve-template.sh` | Template content retrieval through the override stack |

Sources: [.specify/templates/](.specify/templates), [.specify/scripts/bash/](.specify/scripts/bash)

## Integration Manifests

Three integration manifests record platform-specific installations:

| Manifest | Platform | Version | Notable Files |
|----------|----------|---------|---------------|
| `speckit.manifest.json` | Speckit Core | 1.0.8.dev0 | 12 files (scripts + templates) |
| `kimi.manifest.json` | Kimi | 0.16.0 | 15 skill files |
| `zed.manifest.json` | Zed | 1.0.8.dev0 | 10 skill files |

Each manifest records SHA-256 hashes of installed files, enabling drift detection when the speckit core is updated. The `.specify/integration.json` file tracks the active integration platform and its command separator (`.` for Zed, `-` for others).

Sources: [.specify/integrations/](.specify/integrations), [.specify/integration.json](.specify/integration.json)

## The Surgical PR-Fix Agent

Distinct from the Speckit ecosystem is the **surgical-pr-fix** GitHub agent at `.github/agents/surgical-pr-fix.agent.md`. This agent has a narrowly-scoped contract:

- **Input**: A failing GitHub Actions job URL or run/job ID, optionally with a PR number
- **Process**: Extract run/job → grep full log for `##[group]❌ ... (failed)` markers → read failing test → check out PR branch → find repo precedent → apply minimal edit → verify only the failing test file → commit and push
- **Constraints**: Never run the full test suite, never refactor, never tidy adjacent code. One failing test, one minimal fix.

This agent uses GitHub CLI tools (`gh run view`, `gh api`) and operates with `exec`, `read`, `search`, `edit`, and `github/*` tool permissions.

Sources: [.github/agents/surgical-pr-fix.agent.md](.github/agents/surgical-pr-fix.agent.md)

## GYM: Skill Assessment Framework

The `.gym/` directory implements a **GYM (Growth Yard for Muscles)** paradigm for agent skill assessment:

```
.gym/
├── gym.yaml          # Warmup reps + graded exercises definition
├── warmup/           # Mandatory reflex-building reps
│   ├── 01-deps.dart
│   ├── 02-build.dart
│   └── 03-smoke.dart
├── exercises/        # Graded skill proofs
│   ├── exercise-agent-rewrite-zfa-only.dart
│   ├── exercise-extend-zfa-cli.dart
│   └── exercise-generate-feature.dart
└── fixtures/         # Fixed test targets
    ├── plain-dart-package/
    └── sample-crud-package/
```

The `gym.yaml` defines three warmup reps (dependency resolution, build under load, authenticated smoke call) and three graded exercises:

1. **generate-feature**: Scaffold a `Product` feature end-to-end via `GymPlugin.generateWithContext()`, assert four canonical files land on disk
2. **agent-rewrite-zfa-only**: Rewrite a Zuraffa-compatible CRUD package via canonical `zfa` protocol; detect and report plain Dart packages as NOT-ZURAFFA-COMPATIBLE without attempting rewrite
3. **extend-zfa-cli**: Scaffold a new `zfa <name>` subcommand, wire it into a synthetic `CommandRunner`, assert dispatch correctness

The GYM gate (`speckit-gym-gate`) blocks implementation until an operator clears it, and `speckit-gym-run` orchestrates warmup → exercise → gate evaluation.

Sources: [.gym/gym.yaml](.gym/gym.yaml#L1-L84)

## TDD Profile & Memory

The `.specify/memory/tdd-profile.md` records the test stack for the zuraffa repository itself:

- **Language**: Dart 3.13 (stable), `sdk: ^3.11.0`
- **Test runner**: `package:test` (^1.25.0), invoked as `dart test`
- **Static analysis**: `dart analyze` with `package:lints/recommended.yaml`
- **Mutation tool**: None wired in CI; `/speckit.tdd.verify` Phase 4 falls back to deliberate-mutant sampling
- **Coverage**: Opt-in via `dart test --coverage` + `dart run coverage:format_coverage`

The profile records machine-readable command templates for `single`, `file`, `suite`, and `coverage` operations, plus test layout conventions (tests mirror source layout under `test/`) and exemplar references.

Sources: [.specify/memory/tdd-profile.md](.specify/memory/tdd-profile.md)

## Spec Stats Dashboard

The `.specify/stats/SPEC-STATS.md` file provides a portfolio dashboard for all tracked features. As of the last generation, the repository tracks 39 specs across four stages:

| Stage | Count |
|-------|-------|
| specified | 25 |
| planned | 1 |
| implementing | 5 |
| complete | 8 |

The `speckit-spec-stats-*` skills (`open`, `runs`, `report`, `not-green`) provide commands for browsing, querying, and reporting on this portfolio.

Sources: [.specify/stats/SPEC-STATS.md](.specify/stats/SPEC-STATS.md)

## Key Constraints for Agent Consumption

Agents operating within this ecosystem must respect several hard constraints defined across the skill files and `AGENTS.md`:

1. **No-JIT rule**: Every `zfa` child process must be a compiled binary. Never spawn `dart bin/zfa.dart` directly; use `scripts/zfa` or `ZfaExecutable.ensureCompiled`.
2. **STOP-ON-ROADBLOCK**: The first `zfa` command error or unexpected output halts the entire workflow. No workarounds, no partial progress.
3. **Canonical v5 workflow**: `zfa entity create` → `zfa make` → `zfa build`. Never hand-create entities, never call `build_runner` directly.
4. **Branch-name invariant**: The git branch name MUST match the feature directory name exactly (e.g., `specs/010-offline-first-sync` → branch `010-offline-first-sync`).
5. **Never ask, always search**: When information is missing, search the codebase, docs, specs, and `.zfa/` memory before making a default decision. Never formulate a question to the user.

Sources: [AGENTS.md](AGENTS.md#L1-L287)

## Navigation

This page covers the **agent and skill ecosystem** layer. For related context:

- **[CLI Commands & Subcommands](6-cli-commands-and-subcommands)** — The `zfa` command surface that agents drive
- **[TDD Cycle & Spec-Driven Development](13-tdd-cycle-and-spec-driven-development)** — How the TDD extension integrates with the Speckit lifecycle
- **[Proof Receipts & Verification Gates](15-proof-receipts-and-verification-gates)** — The receipt system that agents consult before committing
- **[Configuration & Project Memory (.zfa.json, .zfa/)](4-configuration-and-project-memory-zfa-json-zfa)** — Project memory surfaces agents should consult