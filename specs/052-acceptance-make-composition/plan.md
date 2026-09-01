# Implementation Plan: `zfa tdd compose` — phase-2 acceptance make composition

**Branch**: `052-acceptance-make-composition` | **Date**: 2026-09-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/052-acceptance-make-composition/spec.md` (seeded from GitHub issue #642)

## Summary

Add the missing composition surface that lets a deferred acceptance make
actually flip green at `zfa tdd run` phase 2. `GenerationPlanner.plan()` stays
pure and description-keyed (its unexpressible refusal of acceptance prose is
deterministic and by design); instead, when the planner refuses an
ACCEPTANCE-kind behavior and the feature holds already-green unit subjects,
the make command falls back to a **composition plan** (`compose <id>` →
`build`) executed through the existing `PipelineRunner`. The plan's `compose`
step is a new `zfa tdd compose <behavior-id>` command (wire's sibling) that
implements the acceptance subject by wiring it against the feature's green
unit subject artifacts. The honest stop survives everywhere composition
cannot engage: no green units, unit-kind behaviors, no test-list row, or
prose that stays uncomposable.

## Technical Context

**Language/Version**: Dart 3.13+ (repo pins `sdk: ^3.11.0`; 3.13.2 stable
satisfies it). Flutter 3.47+ is the repo's stated toolchain context, but this
package is pure Dart (no `flutter:` dependency; flutter-tagged tests are
excluded by the fast-suite runner) — no Flutter SDK surface is touched.

**Primary Dependencies**: `args` (command parsing), `path` (path joining),
`package:test` (test runner). No new dependencies.

**Storage**: N/A — file-contract driven (`specs/<feature>/tdd/artifacts.json`
registry, `tdd/cycle-log.md` append-only evidence, `tdd/test-list.md` shared
format, subject files under `lib/`).

**Testing**: `package:test` via `dart test`; fast suite chunked through
`tools/run_tests_chunked.sh` (excludes `flutter`/`slow` tags, clears kernel
caches per chunk). Scenario tests run in the `slow` tier with scripted fake
zfa; the real-pipeline acceptance test uses the SC-017/SC-018 pure-exec
forwarder pattern.

**Target Platform**: CLI (`bin/zfa.dart`) — the zuraffa generation pipeline
and its TDD plugin.

**Project Type**: CLI / code-generation framework plugin (pure Dart).

**Performance Goals**: No runtime-performance surface; the composition
fallback runs only on the planner-refusal path (phase-2 acceptance makes),
one extra subprocess per deferred acceptance behavior.

**Constraints**: Disk-safe verification on cloud agents (chunked runner, no
whole-tree `dart test`); the planner's plan output stays byte-identical
(SC-006); the run driver's contract is untouched (FR-011/FR-012).

**Scale/Scope**: One new command (`compose`), one new pure service
(`composition_planner`), one new pure discovery service
(`composition_targets`), a fallback hook in `make_command.dart`, and
fast/slow tests + spec artifacts. No changes to `run_command.dart`,
`generation_planner.dart`, or `pipeline_runner.dart`.

## Constitution Check

- **Generation-only implementation**: the composed subject is emitted by the
  `zfa tdd compose` pipeline step (a generation command), stamped as
  generated, never hand-written by the driver or the agent — same rule wire
  satisfies for entity wiring (bug #610 design decision).
- **Test ownership (044)**: compose touches only the subject file; the
  paired test file is never modified (FR-004, US2.AC5).
- **Honest evidence**: every compose/build invocation is captured as a
  `GenerationStep` and lands in the green-evidence entry (FR-010); failures
  append no green entry and misfire-stop (047 US4.AC2 unchanged).
- **Planner purity (047 FR-005 / #625 finding 2)**: no phase, run-state, or
  subject knowledge enters `GenerationPlanner`; composition is a separate
  command-layer fallback consuming discovery results passed to it (FR-008).
- **Machine contracts**: compose prints the `compose: behavior=... outcome=...
  feature=...` summary line on every code path (FR-006); make's outcome
  labels and the driver's `[run]` lines are unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/052-acceptance-make-composition/
├── spec.md              # Feature specification (seeded from issue #642)
├── plan.md              # This file
├── research.md          # Key decisions + alternatives considered
├── data-model.md        # Entities: CompositionPlan, ComposableUnitSubject, ComposeOutcome
├── quickstart.md        # The real-pipeline phase-2 flip, runnable by hand
├── contracts/           # compose command contract + make fallback contract
├── checklists/          # pre-delivery checks
├── tasks.md             # Dependency-ordered tasks (MVP-first)
└── tdd/
    ├── test-list.md     # one behavior per line, traced to acceptance criteria
    ├── cycle-log.md     # red/green evidence from /speckit.tdd.run
    └── verification.md  # test-first + mutation evidence audit
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/
├── commands/
│   ├── compose_command.dart        # NEW: zfa tdd compose (wire's sibling)
│   └── make_command.dart           # EDIT: composition fallback on planner refusal
├── services/
│   ├── composition_planner.dart    # NEW: pure fallback planner (acceptance prose → compose+build)
│   └── composition_targets.dart    # NEW: green unit subject discovery (test-list ∩ cycle-log ∩ registry)
└── tdd_plugin.dart / tdd_command.dart  # EDIT: register the compose subcommand

test/plugins/tdd/
├── commands/
│   └── compose_command_test.dart   # NEW: fast-tier unit tests for compose
├── services/
│   └── composition_planner_test.dart  # NEW: planner purity + fallback shaping
└── scenarios/
    └── sc_021_acceptance_composition_e2e_test.dart  # NEW: real-pipeline phase-2 flip
```

No changes to `run_command.dart`, `generation_planner.dart`,
`pipeline_runner.dart`, `step_runner.dart`, or the 047 make pipeline's
existing steps.

## Key Technical Decisions

1. **Composition lives outside the planner** (FR-008). `plan()` is pure and
   description-keyed; threading phase/run-state/subject knowledge into it
   would break SC-006 and reopen the #625 finding-2 concern. The fallback is
   a separate pure service (`CompositionPlanner`) the make command consults
   only after the primary planner refuses.
2. **Green cycle-log evidence is the source of truth for "already-green
   unit subjects"** — not `tdd/run-state.json`. The driver owns run state;
   the make pipeline owns the cycle log (make already reads it for
   certified-red). This keeps make/compose standalone-runnable and
   independent of driver state semantics (Assumptions).
3. **The driver contract is untouched** (FR-011). Phase 2a spawns the same
   `tdd make <id>` and consumes `outcome=green`; the flip happens inside
   make via the fallback. No new driver step, no `step_order` change, no
   run-state schema change — the smallest possible integration surface, and
   the #625/#635 driver tests keep pinning the deferral outcomes.
4. **compose mirrors wire** (bug #610's command design): registry resolution
   rules, stub-signature parsing, ownership refusals, idempotence, and the
   summary-line contract. Reusing wire's proven shape keeps the audit story
   uniform ("the subject is implemented by a generation-pipeline step,
   never by hand").
5. **Discovery = test-list ∩ cycle-log ∩ registry**: a composable anchor is
   a unit-kind `TestListReader` row, with green evidence in the feature's
   cycle log, whose registry record's `subject_path` exists on disk. Any
   green unit with a missing subject file is a misfire, not a silent skip
   (US2.AC4) — partial anchors would make the composed subject lie about
   what it composes.
6. **Every expressible fallback plan terminates in `build`** (047 FR-005
   rule): `compose <id>` → `build`. Compile validation is what makes the
   composed make's target-test pass meaningful.

## Risks & Considerations

- **Accidental honest-stop erosion**: composition must engage ONLY for
  acceptance-kind rows. Guarded by requiring the test-list row's kind; a
  missing/malformed test list leaves the fallback disengaged (fail-closed to
  today's behavior).
- **Test-list unavailability in make**: make currently never reads the test
  list. Discovery wraps the read in the same misfire-stop discipline as the
  driver: a malformed list stops the fallback (non-zero, named error) rather
  than silently composing against unknown kinds.
- **Idempotence across resumed runs**: phase-2a re-attempts after a crash
  re-run the whole make; compose's `already-composed` exit-0 path (wire's
  `already-wired` pattern) keeps the re-attempt green instead of failing on
  a rewritten subject.
- **Disk hygiene**: slow-tier scenario tests spawn temp fixture projects
  (pub get + build_runner). The SC-021 fixture reuses SC-017's provisioning
  shape and cleans up in `tearDown` via the fixture's `dispose()`; the
  chunked runner clears kernel caches between chunks.

## Dependencies

- Spec 047-tdd-make (make pipeline, PipelineRunner, GenerationPlan/Step
  contracts) — the fallback extends this pipeline.
- Spec 046-tdd-verify-red (red evidence contract) — compose's precondition.
- Spec 049-tdd-run (two-phase driving, deferral contracts) — the phase-2
  re-attempt this feature makes real; its contracts are pinned unchanged.
- Bug #610's `zfa tdd wire` — the command shape compose mirrors.
- #625 verification (`.specify/bugs/tdd-run-acceptance-deferral/tdd/
  verification.md`) — flagged the pure planner (finding 2) this feature
  addresses without breaking it.
