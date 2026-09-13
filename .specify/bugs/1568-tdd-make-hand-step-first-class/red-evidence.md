# RED evidence — SPEC 1568 (real runs, pre-fix tree)

- **Recorded**: 2026-09-14, this session, on `feat/1568-tdd-make-hand-step-first-class`
  (working tree, before the implementation landed)
- **Toolchain**: Dart 3.13.3 (stable), linux_x64

## Stage 1 — fast-tier suites (compile red: the API does not exist yet)

```
dart test test/plugins/tdd/services/make_hand_step_1568_test.dart \
          test/plugins/tdd/models/run_state_hand_steps_1568_test.dart \
          test/plugins/tdd/commands/run_driver_hand_step_1568_test.dart

00:00 +0 -3: loading test/plugins/tdd/commands/run_driver_hand_step_1568_test.dart [E]
  Failed to load "test/plugins/tdd/commands/run_driver_hand_step_1568_test.dart":
  test/plugins/tdd/commands/run_driver_hand_step_1568_test.dart:55:9: Error:
  No named parameter with the name 'handStepIds'.
  ...
00:00 +0 -3: Some tests failed.

Failing tests:
  .../run_driver_hand_step_1568_test.dart: loading ... (handStepIds missing on summaryLine)
  .../run_state_hand_steps_1568_test.dart: loading ... (markHandStep/handSteps missing on RunState)
  .../make_hand_step_1568_test.dart: loading ... (MakeOutcome.handStep + HandStepClassifier missing)
```

## Stage 2 — make integration (behavioral red: the #1568 wall, reproduced)

The fixture reproduces the issue's exact shape: U1 traced to a Function-row
contract `scan() -> ScanSession` (entity return), the gen contract-derived
stub with the verbatim entity-typed signature (func refuses it — the #1565
plan-skip fires), certified red, and the post-generation target test still
red.

```
dart test test/plugins/tdd/commands/make_command_hand_step_1568_test.dart

00:37 +3 -2: Some tests failed.

Failing tests:
  A-1568-s1: ... reports outcome=hand-step and exits non-zero
  A-1568-s2: ... the stop message names U1:hand, the declared contract, and the re-run remedy
```

s1's captured actual (the pre-fix classification, verbatim):

```
Expected: contains 'make: behavior=U1 outcome=hand-step feature=090-hand-step-1568'
  Actual: ...
    make: behavior=U1 outcome=generation-error feature=090-hand-step-1568
  Which: does not contain 'make: behavior=U1 outcome=hand-step feature=090-hand-step-1568'
```

— the exact #1568 symptom: the planner-declared hand-step condition graded
`generation-error`.

Passing in red (guards pinning UNCHANGED surfaces, by design):

- A-1568-g1 scalar + undeclared → `outcome=generation-error` (the honest
  generic stop the fix must preserve).
- fixture integrity → the verbatim subject IS the #1565 refused shape.

## Stage 3 — driver suite (compile red)

`run_driver_hand_step_1568_test.dart` fails to load on
`summaryLine(handStepIds:)` (see Stage 1) — the d2/d3/d4 behavioral pins run
after the green landing.
