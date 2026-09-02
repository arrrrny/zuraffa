# Fix: make plan's terminal build step is guarded per-behavior (issue #737)

## What changed

`zfa tdd make` graded ANY pipeline plan failure as `generation-error`. The
plan's terminal `build` step validates the whole project
(build_runner + `dart analyze lib/`), so it can exit non-zero for reasons
the current behavior's generation is not responsible for — e.g. the
pre-existing red suite left by pending `U*` stubs. The make then stopped
`zfa tdd run` on a healthy behavior: the func scaffold had succeeded and
the behavior's own test passed.

The misfire-stop now runs a per-behavior guard before grading: when the
pipeline fails at the plan's TERMINAL `build` step, make runs the CURRENT
behavior's own test (the profile `single` command, e.g.
`dart test test/tdd/u3_test.dart`). If it passes, the build failure is not
attributable to this make — the make takes the #694 skip transition:
`outcome=skipped`, exit 0, green evidence appended, run loop continues.
Anything else keeps the honest `generation-error` stop (safe-failure,
never a silent pass):

- a failed step that is not the terminal `build` (e.g. the `tdd func`
  scaffold itself) → `generation-error` — real generation work never ran;
- a terminal `build` failure with the behavior's own test still red →
  `generation-error` — the generation did not achieve the behavior;
- a launch failure of the per-behavior check → `generation-error`;
- the suite guard (step 9) still re-certifies on the tolerated path and
  still grades attributable NEW failures as `regression` — tolerance
  never bypasses re-certification.

The contract amendment applies to every plan shape (unit, entity/CRUD,
composition) — the composition path hits the same pre-existing-red suite
in phase 2; the A15 test is amended with the issue reference, following
the #694 amendment precedent.

## Files

- `lib/src/plugins/tdd/commands/make_command.dart` — `_toleratedTerminalBuildFailure`
  (terminal-build per-behavior guard), tolerated-path handling
  (skip step 8's duplicate target re-run; `outcome=skipped`), doc comment.
- `test/plugins/tdd/make_command_test.dart` — group
  `bug 737 — the make plan's terminal build step is guarded per-behavior`
  (skip transition, safe-failure control, terminal-only scope) and the
  amended A15.

## Evidence (RED → GREEN, this session)

RED (pre-fix): the new skip-transition test failed with
`Expected: <0> Actual: <1>` and `make: behavior=U3 outcome=generation-error`;
the end-to-end CLI repro on a minimal U1-U4 fixture printed
`generation step failed at index 1 (build generated code for behavior U3)`.

GREEN (post-fix): all 3 bug-737 tests pass; the end-to-end repro prints
`per-behavior check: the behavior's own test passes … taking the #694 skip
transition` and `make: behavior=U3 outcome=skipped` with exit 0 and a green
evidence entry.

See `tdd/verification.md` for the full verification record.
