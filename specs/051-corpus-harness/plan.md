# Implementation Plan: `zfa tdd corpus` — batch loop driving, provenance audit, gap ledger

**Branch**: `051-corpus-harness` | **Date**: 2026-08-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/051-corpus-harness/spec.md`
(seed: GitHub issue #628, epic `045-tdd-full-app-cycle` precondition 5)

## Summary

Deliver the corpus-level orchestrator the epic's proof gate needs: a
`zfa tdd corpus` command family (`run` / `status` / `audit`) that drives every
`ready` feature in the corpus manifest through `zfa tdd run` then
`zfa tdd verify`, persists corpus progress after every feature and resumes
from the first incomplete feature, gates each feature on its verify outcome
(or an explicit recorded waiver), appends every STOP-ON-ROADBLOCK to an
append-only gap ledger, and attributes every file under the app's `lib/` to
a recorded zfa invocation minus the versioned carve-out manifest. The
per-feature machinery (049's `run`, 044's `verify`) is consumed as a
sub-process contract — exit code + machine summary line — exactly the way
049's driver consumes the step commands, so a feature crash can never
corrupt corpus state and a scripted fake zfa drives the whole harness in
tests.

## Technical Context

**Language/Version**: Dart 3.13+ (repo pins `sdk: ^3.11.0`; toolchain 3.13.2
stable). Pure-Dart root package — no Flutter toolchain needed to build, test,
or run.

**Primary Dependencies**: existing internals only — `TddCommand` subcommand
registry (`lib/src/plugins/tdd/commands/`), the step-spawn pattern from
`StepRunner` (`lib/src/plugins/tdd/services/step_runner.dart`: `--zfa-bin`
override, `dart bin/zfa.dart` default, machine-line + exit-code agreement),
the atomic-persistence + in-flight-refusal pattern from `RunStateStore`
(`run_state_store.dart`: temp-file + rename, pid-liveness refusal, dropped
semantics), `MutationGateDecision` labels (`pass` / `fail_survived` /
`fail_timeout` / `preflight_red` / `not_assessed`), and the
`CliRunner(exitOnCompletion: false).runCapturing(...)` in-process test
entry. No new pub dependencies.

**Storage** (all under the driven app's project root, per the corpus
conventions spec 050-corpus-import already pinned):
- `.zfa/manifests/corpus-manifest.json` — input contract from #627
  (`features[{name, ready, reason}]`, `sourceCorpus`, `importedAt`).
- `.zfa/corpus/progress.json` — corpus progress (per-feature state, gate
  outcome, waiver record, in-flight marker, dropped features).
- `.zfa/corpus/gap-ledger.json` — append-only gap ledger.
- `.zfa/corpus/waivers.json` — maintainer-authored verify-gate waivers
  (the only exemption path for a non-passing gate).
- `.zfa/corpus/audit-report.json` — machine-readable audit output.
- `.zfa/manifests/corpus-carveout.json` — versioned carve-out manifest (the
  audit's only file exemption path).
- `.zfa/provenance/*.json` — setup/import provenance records (#626/#627
  will emit theirs; the audit consumes the format).

**Testing**: fast tier for models/services/commands
(`test/plugins/tdd/{models,services,commands}/`) with the spawner injected
as a fake; `@Tags(['slow'])` corpus e2e in `test/plugins/tdd/scenarios/`
driving a 3-feature fixture corpus (complete / gap / not-ready) through a
scripted fake zfa binary, including the resume-after-fix and
concurrent-run refusal scenarios.

**Target Platform**: macOS/Linux CLI (pure Dart).

**Project Type**: CLI plugin command family + services (orchestration
contract).

**Performance Goals**: corpus scale ~120 features; per-feature state in one
JSON file (progress) is O(features) reads/writes — no database, per the
spec's assumption. The audit walks `lib/` once and each provenance source
once: O(files + records).

**Constraints**: STOP-ON-ROADBLOCK at corpus granularity (FR-002) — a
feature-level stop halts the run non-zero before any later feature starts;
the runner never edits a test or source file (the audit/ledger are its only
writes, plus progress); worked-around progress never counts (done only via
the gated loop).

**Scale/Scope**: 3 subcommands, 3 models, 5 services, 6 fast-tier test
files + 1 slow scenario suite; no changes to existing tdd commands.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is the unfilled scaffold template (all
`[PRINCIPLE_*]` placeholders — the repo never ratified a constitution). No
gates are defined; nothing to violate. The de-facto house rules from merged
specs 044–050 all apply and are honored: evidence beats state, honest
stops (never silent absorption), machine-readable summary lines +
documented exit codes, atomic state persistence, sub-process isolation of
driven commands, and read-only consumption of upstream artifacts. No
Complexity Tracking entries needed.

## Project Structure

### Documentation (this feature)

```text
specs/051-corpus-harness/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   └── corpus-harness.md
├── checklists/          # speckit checklist output
└── tdd/                 # tdd extension artifacts (test-list, cycle-log,
                        # verification)
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/
├── commands/
│   ├── corpus_command.dart        # parent `corpus` + subcommand registry
│   ├── corpus_run_command.dart    # zfa tdd corpus run
│   ├── corpus_status_command.dart # zfa tdd corpus status
│   └── corpus_audit_command.dart  # zfa tdd corpus audit
├── models/
│   ├── corpus_manifest.dart       # CorpusFeature, CorpusManifest
│   ├── corpus_progress.dart       # FeatureCorpusState, CorpusProgress,
│   │                              #   CorpusWaiver (per-feature state,
│   │                              #   waiver records, in-flight marker)
│   └── corpus_ledger.dart         # GapLedgerEntry + resolution entries,
│                                  #   issue-status helpers, ledger totals
└── services/
    ├── corpus_manifest_store.dart    # manifest + carve-out reading
    ├── corpus_progress_store.dart    # atomic progress persistence,
    │                                  #   in-flight refusal, dropped marks
    ├── gap_ledger_store.dart         # append-only ledger persistence
    ├── corpus_step_runner.dart       # spawn `tdd run`/`tdd verify`,
    │                                  #   parse machine summary lines
    └── provenance_scanner.dart       # lib/ file -> zfa invocation mapping

test/plugins/tdd/
├── commands/
│   ├── corpus_run_command_test.dart
│   ├── corpus_status_command_test.dart
│   └── corpus_audit_command_test.dart
├── models/
│   └── corpus_models_test.dart
├── services/
│   ├── corpus_manifest_store_test.dart
│   ├── corpus_progress_store_test.dart
│   ├── gap_ledger_store_test.dart
│   ├── corpus_step_runner_test.dart
│   └── provenance_scanner_test.dart
└── scenarios/
    └── corpus_harness_scenario_test.dart   # @Tags(['slow']) 3-feature e2e
```

**Structure Decision**: mirror the tdd plugin's existing
commands/models/services split (the layout specs 044–049 established), with
corpus files named `corpus_*` so the feature's footprint is obvious in
review. The corpus commands register under `TddCommand` so the CLI surface
is `zfa tdd corpus <run|status|audit>` exactly as the spec names it.

## Complexity Tracking

> Not applicable — no constitution violations to justify.
