# Implementation Plan: `zfa tdd verify-red`

**Branch**: `046-tdd-verify-red` | **Date**: 2026-08-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/046-tdd-verify-red/spec.md`

## Summary

Implement `zfa tdd verify-red` — the honest-red gate of the TDD loop (epic
045 precondition 1/5; 041 Phase 7, T055-T061). The command resolves a
behavior's artifacts from the spec-044 registry, runs exactly its test via
the `tdd-profile.md` `single` template, classifies the outcome into six
classes, appends red evidence to `cycle-log.md` only for honest assertion
failures, and never touches `test/` or `lib/`. All building blocks except
the runner wrapper and the classifier already exist (`ArtifactRegistry`,
`CycleLog`, `TddProfile`, `MutationAuditor`'s `Process.run` pattern);
`verify_red_command.dart` is already registered and stubbed.

## Technical Context

**Language/Version**: Dart 3 (repo SDK), CLI plugin architecture
(`package:args/command_runner.dart`).

**Primary Dependencies**: existing zuraffa internals only —
`lib/src/plugins/tdd/services/artifact_registry.dart`,
`lib/src/plugins/tdd/services/cycle_log.dart`,
`lib/src/plugins/tdd/models/tdd_profile.dart`,
`lib/src/plugins/tdd/models/cycle_entry.dart`. No new pub dependencies.

**Storage**: files — `specs/<feature>/tdd/artifacts.json` (read),
`specs/<feature>/tdd/cycle-log.md` (append-only).

**Testing**: `dart test` fast unit tier (no `slow` tag);
`CliRunner(exitOnCompletion: false)` + `Directory.systemTemp` fixtures, per
`test/plugins/tdd/tdd_command_smoke_test.dart` conventions.

**Target Platform**: macOS/Linux CLI (any platform `dart test` runs on).

**Project Type**: CLI plugin command.

**Performance Goals**: single-test execution dominates; command overhead
negligible (<1s excluding the test run itself).

**Constraints**: read-only over `test/`+`lib/`; runner invocation MUST come
from `tdd-profile.md`; misfire-stop on any uncompletable step.

**Scale/Scope**: one command, two new services (~300 LOC), unit + contract
tests.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled template — no
project-specific principles are ratified, so no constitutional gates apply.
The repository-level constraints that do apply (AGENTS.md): no hand-written
workarounds, `zfa build` for codegen, tests via `dart test` presets — all
respected by this design.

**Post-design re-check**: no violations introduced; design adds no new
projects, dependencies, or patterns beyond existing tdd-plugin conventions.

## Project Structure

### Documentation (this feature)

```text
specs/046-tdd-verify-red/
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
│   └── verify_red_command.dart   # IMPLEMENT (currently a misfire-stop stub)
├── services/
│   ├── runner.dart               # NEW — single-test execution via tdd-profile
│   ├── red_classifier.dart       # NEW — six-way outcome classification
│   ├── artifact_registry.dart    # REUSE (findRecord / loadAll)
│   └── cycle_log.dart            # REUSE (append)
└── models/
    ├── cycle_entry.dart          # EXTEND — sourceCriterion, testPath,
    │                             #   timestamp; widen FailureClass
    └── tdd_profile.dart          # REUSE (resolveSingle)

test/plugins/tdd/
├── runner_test.dart              # NEW
├── red_classifier_test.dart      # NEW
└── verify_red_command_test.dart  # NEW (command contract + fixtures)
```

**Structure Decision**: single package, existing tdd-plugin layout; no new
directories beyond three test files and two services.

## Complexity Tracking

No constitution violations; nothing to justify.
