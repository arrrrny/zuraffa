# Implementation Plan: The refactor pass must not strand the green evidence it just certified

**Branch**: `1430-refactor-refresh-evidence` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/1430-refactor-refresh-evidence/spec.md`

## Summary

Within one `zfa tdd run` pass, make certifies green with a `subject-hash`
fingerprint of `lib/tdd/<feature>/<id>_subject.dart`, then the fixed
pass-registry refactor cycle (`zfa build`, `dart format lib/`,
`dart fix --apply lib/`) rewrites that subject without refreshing the
certified hash — so every resume refuses with `subject-drift
(stale-artifacts)` and the loop dead-ends on state it manufactured itself
(issue #1430). Fix shape (research D1): the refactor command, after a green
re-proof whose scope covers every touched behavior's test, appends a
per-behavior **`refresh` cycle-log entry** (new `CycleEntryKind`, #1329
precedent — never `green`, so certification contracts keyed on red+green
stay untouched) carrying the post-rewrite subject-hash, and make's #1036
guard consults that entry before refusing: a last-refresh hash matching the
current on-disk subject (and newer than the certified basis) re-binds the
certified shape — honest loop-caused drift is forgiven, everything else
still refuses byte-identically.

## Technical Context

**Language/Version**: Dart 3.13 stable (pubspec `sdk: ^3.11.0`), pure-Dart root package

**Primary Dependencies**: `package:test` ^1.25.0, `crypto` (sha256), `package:path`, `package:args` — the TDD plugin lives under `lib/src/plugins/tdd/`

**Storage**: append-only markdown evidence (`tdd/cycle-log.md`, sha256 hash-chained per behavior) + proof.v1 receipts under `.zfa/receipts/`

**Testing**: `dart test` (per `.specify/memory/tdd-profile.md`); feature scope `dart test test/plugins/tdd/`; analysis `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`

**Target Platform**: CLI (macOS/Linux/Windows dev machines)

**Project Type**: CLI code generator (zuraffa) with a spec-kit TDD extension

**Performance Goals**: refresh reconciliation adds O(touched subjects) sha256 hashes per refactor pass — sub-100ms

**Constraints**: cycle log is append-only and hash-chained — history is never edited; red/green certification contracts (spec 049) must not observe the new kind

**Scale/Scope**: 3 source files touched (`refactor_command.dart`, `make_command.dart`, `cycle_entry.dart`) + tests; no CLI surface change

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution (`.specify/memory/constitution.md`) is the unfilled
spec-kit template — no project-specific gates are declared. The repo's
 operative contracts this plan must honor (from AGENTS.md and the code's own
documented invariants):

- **Test-first**: every behavior lands red-first via `zfa tdd` (this feature dogfoods the loop it fixes — noting the loop's known defect is the subject of this feature; the manual `--re-certify` workaround from the issue text is the sanctioned bridge if the loop strands mid-feature).
- **Errors-are-an-API**: the guard's refusal stays for genuine drift; the new accept path prints its own provenance note.
- **Append-only evidence**: no cycle-log history edits; the refresh lands as a new entry.

**Verdict**: PASS (no violations).

## Project Structure

### Documentation (this feature)

```text
specs/1430-refactor-refresh-evidence/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── refactor-refresh.md  # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/
├── commands/
│   ├── refactor_command.dart   # Post-re-proof refresh reconciliation (the writer)
│   └── make_command.dart       # _subjectDriftRefusal consults the refresh entry (the reader)
├── models/
│   └── cycle_entry.dart        # CycleEntryKind.refresh + label + rendering
└── services/
    └── cycle_evidence.dart     # (no change — generic kind parse already reads `refresh`)

test/plugins/tdd/               # behavior tests beside the plugin's existing suites
```

**Structure Decision**: Single-package change inside the existing TDD plugin;
tests mirror the existing `test/plugins/tdd/` layout (per the tdd-profile).

## Complexity Tracking

> No constitution violations to justify.
