# Implementation Plan: `zfa tdd refactor`

**Branch**: `048-tdd-refactor` | **Date**: 2026-08-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/048-tdd-refactor/spec.md`

## Summary

Implement `zfa tdd refactor` — the green-only refactoring step of the TDD
loop (epic 045 precondition 3/5; 041 Phase 9, T066-T069). The command
preflights the full suite via the project `tdd-profile.md` (refusing on any
red, no skip option), applies a small fixed set of idempotent tool-driven
normalization passes (`zfa build`, `dart format`, `dart fix`) that may only
touch `lib/`, re-proves the suite, and appends refactor evidence to
`cycle-log.md`. It mirrors the post-`43841d0c` `verify_red_command.dart`
conventions, including the `--project` flag and summary-line contract.

## Technical Context

**Language/Version**: Dart 3 (repo SDK), CLI plugin architecture
(`package:args/command_runner.dart`).

**Primary Dependencies**: existing zuraffa internals —
`cycle_log.dart`, `cycle_entry.dart`, `tdd_profile.dart`, `runner.dart`,
`mutation_auditor.dart`'s suite `Process.run` pattern. External tools invoked
as sub-processes: `zfa build` (self), `dart format`, `dart fix`. No new pub
dependencies.

**Storage**: files — `specs/<feature>/tdd/cycle-log.md` (append-only
evidence); `.specify/memory/tdd-profile.md` (read).

**Testing**: fast unit tier for services; `@Tags(['slow'])` subprocess
command/scenario tests mirroring `verify_red_command_test.dart` and
`TddFixture`.

**Target Platform**: macOS/Linux CLI.

**Project Type**: CLI plugin command.

**Performance Goals**: dominated by the two full-suite runs (preflight +
re-proof); passes are idempotent tools. No added constraints.

**Constraints**: test-directory checksum immutability; every `lib/` change
attributable to a recorded tool command; no preflight skip option;
misfire-stop on any failing tool action.

**Scale/Scope**: one command + two new services + model extension
(~450 LOC), tests included.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled template — no
ratified gates. AGENTS.md constraints respected: tool-driven changes only,
`zfa build` for codegen, `dart test` presets.

**Post-design re-check**: no violations; no new dependencies or layers.

## Project Structure

### Documentation (this feature)

```text
specs/048-tdd-refactor/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/
├── commands/
│   └── refactor_command.dart        # IMPLEMENT (currently misfire-stop stub)
├── services/
│   ├── refactor_passes.dart         # NEW — the fixed pass registry + executor
│   ├── tree_snapshot.dart           # NEW — shared test/lib tree diff
│   │                                #   (extracted from verify_red's private
│   │                                #   _ReadOnlyTreeSnapshot, generalized)
│   └── runner.dart                  # EXTEND — suite template + runSuite
└── models/
    ├── cycle_entry.dart             # EXTEND — CycleEntryKind.refactor,
    │                                #   relaxed assert, label fix, actions list
    └── refactor_action.dart         # NEW — RefactorAction + RefactorOutcome

test/plugins/tdd/
├── services/
│   ├── refactor_passes_test.dart    # NEW (fast)
│   └── tree_snapshot_test.dart      # NEW (fast)
├── refactor_command_test.dart       # NEW (slow)
└── scenarios/
    ├── sc_010_refuses_red_suite_test.dart
    ├── sc_011_tool_only_and_test_immutable_test.dart
    └── sc_012_reproves_green_test.dart
```

**Structure Decision**: existing tdd-plugin layout; the tree-snapshot helper
is promoted from `verify_red_command.dart`'s private class into a shared
service (verify_red keeps working unchanged; de-duplication lands here
because refactor needs the same guard).

## Complexity Tracking

No constitution violations; nothing to justify.
