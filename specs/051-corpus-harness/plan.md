# Implementation Plan: `zfa tdd corpus` — batch driving, provenance audit, gap ledger

**Branch**: `051-corpus-harness` | **Date**: 2026-08-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/051-corpus-harness/spec.md`

## Summary

Implement the corpus-level orchestrator for the TDD cycle (issue #628): a new
`zfa tdd corpus` subcommand group with `run`, `audit`, and `status` verbs.
`corpus run` drives every `ready` feature from the corpus manifest
(#627's `.zfa/manifests/corpus-manifest.json`) through the existing
`zfa tdd run` then `zfa tdd verify` per-feature commands, persisting
corpus-level progress after each feature and resuming from the first
incomplete feature on re-run. Stops honestly on any per-feature failure
(STOP-ON-ROADBLOCK), appending a gap-ledger entry. `corpus audit` attributes
every `lib/` file to a logged zfa invocation or a declared carve-out.
`corpus status` reports per-state counts, gate outcomes, and ledger totals.
The gap ledger is the append-only record of every misfire, with issue-link
fields for zuraffa gap-tracking.

## Technical Context

**Language/Version**: Dart 3 (repo SDK `^3.11.0`), CLI plugin architecture.

**Primary Dependencies**: existing internals only — `RunCommand`,
`VerifyCommand` (spawned as sub-processes), `CorpusManifest` (#627),
`RunStateStore` pattern (replicated at corpus level), `CycleEvidence`
(for provenance extraction), `MutationAuditReport` (for gate outcomes).
No new pub dependencies.

**Storage**: `<app>/.zfa/corpus/progress.json` (per-feature states +
in-flight marker), `<app>/.zfa/corpus/gap-ledger.json` (append-only),
`<app>/.zfa/corpus/provenance.json` (file→invocation mapping),
`<app>/.zfa/corpus/carve-out.json` (manual-UI exemption list).

**Testing**: fast unit tier: stores, models, ledger, auditor with
in-memory/temp-dir fixtures; contract tests for machine-readable summary
lines. No subprocess-based integration tests in the fast tier (those
exercise the real `zfa` binary and belong in slow-tier scenarios).

**Target Platform**: macOS/Linux CLI.

**Project Type**: CLI command group + shared services.

**Performance Goals**: file-read class; 120-feature corpus status in
milliseconds; full corpus run bounded by per-feature subprocess time.

**Constraints**: append-only ledger (never edit past entries); STOP-ON-ROADBLOCK
at corpus granularity (one failed feature halts the whole run); verify gate
outcomes are first-class (NOT_ASSESSED stops, waivers are explicit and
recorded); provenance audit must attribute 100% of `lib/` files.

**Scale/Scope**: ~120 features; per-feature state files and aggregate
progress file suffice (no database). One top-level command group + three
services + four models (~800 LOC), tests included.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled template — no
ratified gates. AGENTS.md constraints respected: the corpus harness only
orchestrates existing `zfa tdd run` / `zfa tdd verify` commands and
reads their outputs; it never hand-writes production code. The STOP-ON-ROADBLOCK
rule is honored by design — any feature-level stop halts the corpus run and
records the gap in the ledger.

**Post-design re-check**: no violations; no new dependencies or layers.

## Project Structure

### Documentation (this feature)

```text
specs/051-corpus-harness/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
lib/src/
├── plugins/tdd/
│   ├── commands/
│   │   └── corpus_command.dart          # NEW — top-level `tdd corpus`,
│   │                                    #   subcommands: run, audit, status
│   ├── models/
│   │   ├── corpus_feature_progress.dart  # NEW — per-feature corpus state
│   │   ├── gap_ledger_entry.dart         # NEW — append-only stop record
│   │   ├── provenance_record.dart        # NEW — file→invocation mapping
│   │   └── carve_out_entry.dart          # NEW — manual-UI exemption
│   └── services/
│       ├── corpus_progress_store.dart    # NEW — atomic persist + in-flight guard
│       ├── corpus_runner.dart            # NEW — orchestrates run→verify per feature
│       ├── gap_ledger.dart               # NEW — append-only ledger service
│       ├── provenance_auditor.dart       # NEW — attributes lib/ files
│       └── carve_out_manifest.dart       # NEW — reads versioned exemption list
├── commands/
│   └── tdd_command.dart                  # EXTEND — register CorpusCommand
└── core/project/
    └── corpus_manifest.dart              # FROM #627 — read-only dependency

test/plugins/tdd/
├── commands/
│   └── corpus_command_test.dart          # NEW (fast) — command surface + contract
├── models/
│   ├── corpus_feature_progress_test.dart # NEW (fast)
│   ├── gap_ledger_entry_test.dart        # NEW (fast)
│   └── provenance_record_test.dart       # NEW (fast)
├── services/
│   ├── corpus_progress_store_test.dart   # NEW (fast) — concurrency, resume
│   ├── corpus_runner_test.dart           # NEW (fast) — 3-feature fixture
│   ├── gap_ledger_test.dart              # NEW (fast) — append-only, history
│   ├── provenance_auditor_test.dart      # NEW (fast) — attribution + failure
│   └── carve_out_manifest_test.dart      # NEW (fast)
└── scenarios/
    └── sc_019_corpus_harness_e2e_test.dart  # NEW (slow) — full 3-feature fixture
```

**Structure Decision**: the corpus command lives inside the TDD plugin
(`commands/corpus_command.dart`) because it orchestrates TDD commands; services
and models are siblings of the existing TDD services/models. The manifest
model (`CorpusManifest`) stays in `core/project/` from #627 — read-only
dependency, never modified by this feature.

## Complexity Tracking

No constitution violations; nothing to justify.
