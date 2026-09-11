# Tasks: make gates on errors only — warnings are non-blocking and consistent across lanes

**Input**: Design documents from `/specs/1407-make-gate-errors-only/`

**Prerequisites**: spec.md, plan.md

**Tests**: TDD per the spec-whole flow — every behavior gets a failing test first (`tdd/test-list.md` is the behavior list; this file carries the non-behavior remainder).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1/US2/US3)

## Path Conventions

Repo-local TDD plugin: `lib/src/plugins/tdd/` (commands + models + services), tests in `test/plugins/tdd/`.

## Phase 1 — Setup

- [x] T001 Confirm the defect surface on the head tree: the build command's
  analyze gate refuses on errors OR warnings (`lib/src/commands/build_command.dart`,
  issue #1035 message contract); the make grades a failed terminal build step
  through `_toleratedTerminalBuildFailure` whose #942 gate reads
  `BuildCommand.analyzeReportsError` (errors only) but whose target-test
  requirement still grades the make on a red test — a warnings-only refusal +
  red skin-lane test = `outcome=generation-error` (the issue's real-world W3
  shape); the #694 skip transition runs no gate at all. Fix surface confirmed:
  `lib/src/plugins/tdd/commands/make_command.dart` only.

## Phase 2 — Foundational

- [x] T002 [P] Seed the behavior suite `test/plugins/tdd/bug_1407_make_gate_errors_only_test.dart`
  on the existing `TddFixture` conventions (hermetic temp project, fake zfa
  bin with `exitByArgv`/`stdoutByArgv`/`sideEffectByArgv`, real `dart test`
  children): fixture helpers for a warnings-only build-gate refusal (the
  build command's own 0-error message + one `warning -` line, exit 1), an
  errors refusal (one `error -` line, exit 1), and a profile writer able to
  set/clear the `analyze-gate:` key in the machine-readable Keys block.

## Phase 3 — User Story 1: a warning never fails a make (P1) 🎯 MVP

**Goal**: A warnings-only analyze-gate refusal never flips the make's
outcome; the warnings are logged; only errors stop the make.

**Independent Test**: A certified-red behavior whose terminal build step is
refused 0-errors+1-warning and whose target test passes after generation
completes `outcome=green`, exit 0, warnings logged (today:
`green-with-failed-build`).

- [x] T003 [US1] [behavior: A-1407-1] (MANDATORY) RED: skin-lane widget
  behavior, warnings-only refusal, target test green after the view step →
  `outcome=green`, exit 0, the `warnings are non-blocking` verdict line and
  the warning line logged, green evidence appended (fails: today the refusal
  reaches the tolerance and records `green-with-failed-build`)
- [x] T004 [US1] [behavior: U-1407-4] (MANDATORY) RED: engine-lane unit
  behavior, identical warnings-only refusal, target test green after the func
  scaffold → `outcome=green`, exit 0, identical gate verdict line (fails:
  same `green-with-failed-build` shape)
- [x] T005 [P] [US1] [behavior: U-1407-1] Characterization pin: warnings-only
  refusal + target test still red after generation → `outcome=generation-
  error`, exit 1, no green entry, subject restored (the red test decides,
  not the warning; must stay green through the fix)
- [x] T006 [P] [US1] [behavior: U-1407-2] Characterization pin: build verdict
  carrying 1 error → the #942 refusal byte-identical (`outcome=generation-
  error`, the `analyzer error(s)` note, no green entry; must stay green
  through the fix)

## Phase 4 — User Story 2: the same gate strictness for every lane and transition (P2)

**Goal**: The errors-only grading is structurally shared; the skip
transition matches.

**Independent Test**: Widget-lane and unit-lane makes under identical
warnings-only refusals produce the same outcome token and verdict line; an
already-green sibling reports `skipped`.

- [x] T007 [US2] [behavior: A-1407-2] (MANDATORY) Cross-lane pair
  assertion inside T003/T004's rows: the two lanes' outputs share the
  outcome token `green` and the same verdict-line text (behavior id and plan
  steps aside) — proves one shared gate object
- [x] T008 [P] [US2] [behavior: A-1407-3] Characterization pin: an
  already-green sibling in the same feature takes the #694 skip transition
  (`outcome=skipped`, exit 0) — the gate's warning strictness matches the
  normal transition's (non-blocking in both; must stay green through the fix)

## Phase 5 — User Story 3: projects that rely on warnings being blocking can opt back in (P3)

**Goal**: The profile opt-in restores the legacy strictness; every other
profile state defaults to errors-only.

**Independent Test**: `analyze-gate: warnings-blocking` + warnings-only
refusal + green target test → `green-with-failed-build` (pre-#1407
grading); absent key / explicit `errors-only` / unrecognized value → the
US1 behavior.

- [x] T009 [US3] [behavior: U-1407-3] (MANDATORY) Opt-in pin:
  `analyze-gate: warnings-blocking` in the Keys block → the pre-#1407
  grading applies (`outcome=green-with-failed-build`, exit 0) — the
  warnings-only refusal reaches the #737/#942 tolerance unchanged
- [x] T010 [P] [US3] [behavior: U-1407-5] Default pins: profile without the
  key (covered by T003), profile with explicit `analyze-gate: errors-only`,
  and profile with an unrecognized value (`analyze-gate: strict-everything`)
  → all behave identically to the default (`outcome=green` under a
  warnings-only refusal with a green target test)

## Phase 6 — Implementation (non-behavioral remainder)

- [x] T011 [US1] GREEN: the errors-only gate in
  `lib/src/plugins/tdd/commands/make_command.dart` —
  `_analyzeGateRefusalPattern` (the build gate's single-writer message),
  `_isWarningsOnlyBuildGateRefusal` (terminal build step precondition +
  0-error verdict + shared-parser cross-check), `_logWarningsOnlyGateRefusal`
  (verdict line + capped warning lines), `_profileWarningsBlocking` (the
  AC4 reader), and the branch in the `!pipelineResult.completed` block that
  falls through to the normal flow (depends on T003/T004 red)
- [x] T012 [P] Edge pins (same suite): a build failure WITHOUT the gate
  message (build_runner-style failure) keeps the #737 tolerance path;
  a gate message with 0 errors but raw `error -` lines in the output keeps
  the honest stop (shared parser wins); voluminous warnings log a capped
  sample with a remainder count (depends on T011)
- [x] T013 Regression sweep: the existing tolerance-family suites stay green
  (`test/plugins/tdd/make_command_test.dart` #737/#942 group,
  `test/commands/build_command_unit_test.dart` parser group);
  `dart analyze` on the changed files reports 0 errors / 0 warnings;
  `dart format` clean (depends on T011)

## Phase 7 — Verification

- [x] T014 (MANDATORY) `/speckit.tdd.verify`: record the red→green evidence
  per behavior, the deliberate mutant (kill proof), and the AC/FR coverage
  matrix in `tdd/verification.md` (depends on T011–T013)

## Dependencies

- T002 → T003–T010 (the suite scaffolding precedes every behavior row)
- T003, T004 (red) → T011 (the implementation turns them green)
- T011 → T005–T010 stay green (pins) and T012/T013/T014 (edge pins,
  regression sweep, verification)

## Parallelism

- T002, T005, T006, T008, T010 are independent of the US1 red rows and can
  land in any order before T011's green.
- T012/T013/T014 depend only on T011.
