# Implementation Plan: `zfa tdd make`

**Branch**: `047-tdd-make` | **Date**: 2026-08-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/047-tdd-make/spec.md`

## Summary

Implement `zfa tdd make` — the generation-only green step of the TDD loop
(epic 045 precondition 2/5; 041 Phase 8, T062-T065). The command mirrors the
merged `verify_red_command.dart` conventions (registry resolution, profile
runner, cycle log, summary line, read-only guard), adds three new services —
a generation planner (behavior → minimal pipeline plan, misfire when
unexpressible), a pipeline runner (zfa sub-process invocation with captured
steps), and a suite guard (pre/post full-suite baseline diff) — extends
`SingleTestRunner` with the `suite` profile template, and extends
`CycleLogEntry` to record generation steps in green evidence.

## Technical Context

**Language/Version**: Dart 3 (repo SDK), CLI plugin architecture
(`package:args/command_runner.dart`).

**Primary Dependencies**: existing zuraffa internals only —
`artifact_registry.dart`, `cycle_log.dart`, `runner.dart`,
`red_classifier.dart`, `tdd_profile.dart`, `cycle_entry.dart`. Pipeline
invoked as sub-processes of the `zfa` CLI itself (`entity create`, `make`,
`build`). No new pub dependencies.

**Storage**: files — `specs/<feature>/tdd/artifacts.json` (read),
`specs/<feature>/tdd/cycle-log.md` (read red evidence, append green).

**Testing**: `dart test` fast unit tier for services; `@Tags(['slow'])`
subprocess tests for the command end-to-end (mirroring
`verify_red_command_test.dart`, which already runs tagged-slow).

**Target Platform**: macOS/Linux CLI.

**Project Type**: CLI plugin command.

**Performance Goals**: dominated by `zfa build` (build_runner) — tens of
seconds per behavior is acceptable; no added constraints.

**Constraints**: never writes/edits production source directly; never
modifies test files; all runner invocations from `tdd-profile.md`;
misfire-stop on any uncompletable step.

**Scale/Scope**: one command implementation + three new services + two
extensions (~600 LOC), tests included.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled template — no
ratified project principles, so no constitutional gates apply. AGENTS.md
constraints respected: no hand-written production source in target projects,
generation via `zfa make`/`entity create`/`zfa build` only, tests through
`dart test` presets.

**Post-design re-check**: no violations; design reuses existing tdd-plugin
conventions and adds no new dependencies or project layers.

## Project Structure

### Documentation (this feature)

```text
specs/047-tdd-make/
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
│   └── make_command.dart            # IMPLEMENT (currently misfire-stop stub)
├── services/
│   ├── generation_planner.dart      # NEW — behavior → minimal pipeline plan
│   ├── pipeline_runner.dart         # NEW — zfa sub-process steps + capture
│   ├── suite_guard.dart             # NEW — baseline capture + NEW-failure diff
│   └── runner.dart                  # EXTEND — load suite template
└── models/
    ├── cycle_entry.dart             # EXTEND — generationSteps on green entries
    └── generation_plan.dart         # NEW — plan/step value objects

test/plugins/tdd/
├── services/
│   ├── generation_planner_test.dart # NEW
│   ├── pipeline_runner_test.dart    # NEW
│   └── suite_guard_test.dart        # NEW
├── make_command_test.dart           # NEW (slow-tagged, like verify_red's)
└── scenarios/
    ├── sc_005_turns_red_green_test.dart
    ├── sc_006_requires_certified_red_test.dart
    ├── sc_007_regression_guard_test.dart
    └── sc_008_misfire_stop_test.dart
```

**Structure Decision**: single package, existing tdd-plugin layout; mirrors
the 046 file placement one-for-one.

## Complexity Tracking

No constitution violations; nothing to justify.
