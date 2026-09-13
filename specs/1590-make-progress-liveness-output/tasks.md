**Template Version**: `zuraffa-1.0`

# Tasks: 1590-make-progress-liveness-output

**Input**: Design documents from `specs/1590-make-progress-liveness-output/`

**Prerequisites**: plan.md (required), spec.md (required)

Dependency-ordered, MVP-first. Every behavior task carries a
`[behavior: <id>]` marker and is MANDATORY (never skippable) — the test
must be written and certified red BEFORE its implementation task.

## Phase 1 — Foundational (tee primitive, no behavior change)

- [ ] T001 In `lib/src/plugins/tdd/services/tdd_timeout.dart`, add the
      optional `void Function(String line)? onStdoutLine` parameter to
      `runTimed`: when set, the decoded stdout stream feeds the returned
      `ProcessResult.stdout` byte-faithfully AND fires the callback per
      complete line as it arrives (carry-accumulator; `\r\n` tolerated;
      final unterminated line flushed at done). Null (the default) keeps
      the pre-#1590 `.join()` path exactly. Add
      `parseTddHeartbeatSeconds(String? raw)` beside
      `parseTddTimeoutMinutes`: null/empty → 30s default is the CALLER's
      decision (helper returns null); `0` → [Duration.zero] (off);
      positive (fractions allowed) → the [Duration]; anything else throws
      [TddTimeoutFormatException] with the same message shape.
- [ ] T002 In `lib/src/plugins/tdd/services/pipeline_runner.dart`, add the
      static banner helpers: `String bannerFor(GenerationStepSpec spec)`
      (the `→ ` line per FR-002's derivation, build carries the
      `build_runner + analyze; minutes on first run` hint) and
      `String nameFor(GenerationStepSpec spec)` (FR-003's name, hint
      omitted). Pure — no printing, no I/O.

## Phase 2 — Behaviors (US1: what is about to run)

- [ ] T003 [behavior: U-1590-1] RED first: in
      `test/plugins/tdd/issue_1590_progress_liveness_test.dart`, assert
      `PipelineRunner.nameFor`/`bannerFor` mapping is exact per SC-2
      (func / build-with-hint / entity create User / make User /
      mock create / two-arg fallback) and `runPlan` prints exactly one
      `→ ` banner per spawned sub-step, each BEFORE its spawn (capturePrint
      zone + the fake zfa bin, ordering asserted by index).
- [ ] T004 [behavior: U-1590-2] RED first: same file, assert make's plan
      line names the steps (SC-6): `   plan: 2 step(s): func, build` for a
      unit-kind plan via the plan-line builder used by make_command, and
      the composition-fallback shape names `compose, build`.
- [ ] T005 [behavior: U-1590-3] RED first: same file, assert the driver's
      step-start line builder (`RunDriverCore.stepStartLine`) renders
      `[run] A1 make — generation pipeline (sub-steps announced as they
      start)` and the static hints for gen/verify-red/refactor per FR-001,
      and appends the FR-007 resume suffix exactly when the loaded
      in-flight trio names this behavior+step with a foreign pid
      (SC-5's `(resuming in-flight step from run-state.json, owner pid
      <pid>)`).
- [ ] T006 [behavior: U-1590-4] RED first: same file, assert
      `RunDriverCore.heartbeatLine('A1', 'make', elapsed)` renders
      `[run] A1 make … <elapsed> elapsed` with `formatTddTimeout`
      formatting, and `parseTddHeartbeatSeconds` maps '0' → zero (off),
      '0.05' → 50ms, garbage → [TddTimeoutFormatException].
- [ ] T007 [behavior: U-1590-5] RED first: same file, assert the runTimed
      tee (FR-004/SC-3 plumbing): a spawned script printing `→ live-banner`
      and `plain line` fires the callback with BOTH lines in order, and
      the returned `ProcessResult.stdout` equals the pre-#1590 join
      (byte-faithful capture).
- [ ] T008 [behavior: A-1590-1] RED first: in
      `test/plugins/tdd/run_command_test.dart`, drive the full loop with
      the fake zfa bin and assert SC-1: for every spawned step the output
      contains `[run] <id> <step> — ` positioned BEFORE that step's
      `[run] <id> <step> -> ` completion line (SC-1), and the machine
      contract lines are unchanged (SC-8 smoke).
- [ ] T009 [behavior: A-1590-2] RED first: same suite, make the fake zfa
      bin print `→ live-banner` + `plain child line` for the make argv:
      default mode forwards `→ live-banner` only (SC-3); `--verbose`
      forwards both verbatim (SC-7); `--heartbeat 0` prints no heartbeat
      line while `--heartbeat 0.05` against a sleeping fake child prints
      at least one `… elapsed` line (SC-4).

## Phase 3 — Behavior implementations (green the behaviors)

- [ ] T010 [behavior: U-1590-1] `PipelineRunner.runPlan`: print
      `bannerFor(spec)` via `print()` immediately before each `runTimed`
      spawn (FR-002; spawned steps only — the misfire-stop paths stay
      banner-free).
- [ ] T011 [behavior: U-1590-2] `make_command.dart`: render both plan
      lines with the step names via `PipelineRunner.nameFor` (FR-003):
      `   plan: <n> step(s): <names>` and the composition-fallback
      variant.
- [ ] T012 [behavior: U-1590-3] `run_driver_core.dart`: add
      `static String stepStartLine(...)` (FR-001/FR-007) and print it in
      `_driveBehavior` after `tx.begin` and before `runner.run(…)`; add
      `verbose`/`heartbeat` to `drive(...)`, store as instance state, and
      build the `StepRunner` with an `onChildLine` forward that prints
      `^→ ` lines by default and everything under `--verbose` (FR-005).
- [ ] T013 [behavior: U-1590-4] `run_driver_core.dart`: add
      `static String heartbeatLine(...)`; in `_driveBehavior` wrap the
      `runner.run(…)` await with the FR-006 `Timer.periodic` heartbeat
      (canceled in the existing try's `finally`).
- [ ] T014 [behavior: U-1590-5] `lib/src/plugins/tdd/services/step_runner.dart`:
      add optional `onChildLine` to the constructor, forwarded by the
      DEFAULT spawner into `runTimed(onStdoutLine: …)`; document that
      injected spawner fakes keep their own contract (FR-004).
- [ ] T015 [behavior: A-1590-1/A-1590-2] `run_command.dart`,
      `run_engine_command.dart`, `run_skin_command.dart`: add `--verbose`
      flag + `--heartbeat <seconds>` option (shared help consts), thread
      both into `core.drive(...)` / `driver.drive(...)` for every lane.

## Phase 4 — Polish & docs (non-behavioural)

- [ ] T016 Update the machine-contract docs: `run_command.dart` library
      doc (lines 33–41) and `run_driver_core.dart`'s byte-identity claim
      gain the #1590 additive-line carve-out (step-start banners, tee'd
      `→ ` lines, heartbeats; `--heartbeat 0` for strict parsers).
- [ ] T017 `dart analyze` clean on all changed files; `dart format` clean;
      re-run the affected fast-tier suites + the slow-tier run suite.

## Phase 5 — Verification

- [ ] T018 Record red evidence (pre-implementation run outputs) under
      `specs/1590-make-progress-liveness-output/tdd/`, drive every
      behavior green, and write `tdd/verification.md` against SC-1…SC-8.

Non-behavioural tasks (no red phase): T001, T002, T016, T017 — foundational
plumbing, static helpers, docs, and gates. T018 is the verification pass.
Every T003–T015 marker names its behavior; a behavior closes only when its
test is green AND its implementation landed.
