**Template Version**: `zuraffa-1.0`

# Tasks: 991-non-scalar-param-hand-delta-seam

Dependency-ordered, MVP-first. Every behavior task carries a
`[behavior: <id>]` marker and is MANDATORY (never skippable) — the test
must be written and certified red BEFORE its implementation task.

## Phase 1 — Foundational (detection vocabulary)

- [x] T001 Add `MakeOutcome.handDeltaRequired` with label
      `hand-delta-required` to
      `lib/src/plugins/tdd/models/generation_plan.dart` (doc comment
      naming issue #1323 and the #1036 failed-make contract).
- [x] T002 Create `lib/src/plugins/tdd/services/arg_placeholder.dart`:
      the `ArgPlaceholderHit` value object (index, target, declaredType)
      and `argPlaceholderHitOf({testContent, runOutput})` implementing the
      two-signal detection (FR-001): the generated `_argN()` helper
      marker in the test content AND the "provide a representative
      argument for" token in the failing transcript; both must agree.
      Export the shared remedy builder `argPlaceholderRemedy(...)`
      (placeholder, project-relative test path, declared type, re-run
      command) so make and the run driver never drift on the wording.

## Phase 2 — Behavior: make surfaces the hand-delta seam (US1)

- [x] T003 [behavior: U-1323-1] RED first: in
      `test/plugins/tdd/issue_1323_hand_delta_seam_test.dart`, seed a
      certified-red behavior whose generated test carries an `_arg0()`
      helper (`Object`-typed declared param), run `zfa tdd make` with a
      fake `zfa` pipeline that leaves the test failing, and assert
      `outcome=hand-delta-required` + the exact remedy line + no green
      evidence.
- [x] T004 [behavior: U-1323-2] RED first: same fixture but the failing
      transcript does NOT carry the placeholder token (unrelated red) —
      make keeps the honest generic `outcome=generation-error`.
- [x] T005 Implement the step-8 diagnosis arm in
      `lib/src/plugins/tdd/commands/make_command.dart`: before the
      generic still-failing stop, run `argPlaceholderHitOf` over the test
      content + post-run transcript; on a hit print the exact edit,
      restore the subject (#1036), stop exit 1 with
      `outcome=hand-delta-required`. (T003/T004 green.)

## Phase 3 — Behavior: `_scalarLiteral` covers `Object` (US2, preferred path)

- [x] T006 [behavior: U-1323-3] RED first: in
      `test/plugins/tdd/issue_1323_hand_delta_seam_test.dart`, drive the
      behavior test writer for a contract shape with an `Object`-typed
      param (`reason(Object error) -> String`) and assert the generated
      test passes `Object()` at the capture site and contains NO
      `_arg` helper; assert the scalar literals are unchanged
      (`'sample'`, `0`, `false`, `0.0`) for `String`/`int`/`num`/`bool`/
      `double` params (FR-004, FR-007).
- [x] T007 Implement: add `case 'Object': return 'Object();'` to
      `_scalarLiteral` in
      `lib/src/plugins/tdd/services/behavior_test_writer.dart`.
      (T006 green.)

## Phase 4 — Behavior: re-certification after the hand-edit (US3)

- [x] T008 [behavior: U-1323-4] RED first: end-to-end re-certification —
      the U-1323-1 fixture, then hand-edit the generated test (replace
      `_arg0()` with `StateError('boom')` as a representative `Object`
      the capture does NOT swallow), re-run make with the fake pipeline
      now generating the real implementation, and assert the drift check
      re-ran the UPDATED test (red re-certified) and make completes
      `outcome=green` (FR-005, SC-2).
- [x] T009 Pin FR-005 in `arg_placeholder.dart` docs + make's drift-check
      comment: the certified-red precondition never short-circuits the
      drift re-run (documentation task, verified by T008).

## Phase 5 — Behavior: run driver hand step (US4)

- [x] T010 [behavior: U-1323-5] RED first: in
      `test/plugins/tdd/issue_1323_hand_delta_driver_test.dart`, script
      the fake `zfa` so make prints
      `outcome=hand-delta-required`, drive the real run driver, and
      assert `stopped_at=<id>:hand` + the remedy line naming the exact
      edit (FR-006, SC-5).
- [x] T011 Implement the driver arm in
      `lib/src/plugins/tdd/commands/run_driver_core.dart`: key on
      `step == 'make' && outcome == 'hand-delta-required'` BEFORE the
      generic honest stop; advance state generically; print the remedy;
      report `stopped_at=<id>:hand`. (T010 green.)

## Phase 6 — Polish

- [x] T012 Run `dart analyze` on the changed files, `dart test` for the
      touched suites, and `dart format .` (zero formatting diffs).
- [x] T013 Cross-artifact consistency: spec ACs ↔ test-list behaviors ↔
      tasks; update this file's checkboxes as tasks complete.
