# Cycle Log: bug #718 — tdd make fails on unit behaviors (U5+)

Append only. Newest last. Every entry's `red` block is the evidence that
the test existed and failed before the implementation.

## Baseline

- suite: fast tier chunked (`tools/run_tests_chunked.sh` folder-per-chunk)
  -> 2351 passed, 2 failed; both failures pre-existing on the pristine
  base (`refactor_passes_test.dart` U2 and bug-#689 entrypoint tests,
  verified failing identically with the branch's changes stashed).
- tdd plugin slow tiers at base: `make_command_test.dart --preset=all`
  24 passed / 2 failed (bug-657 "names the verb" + spec-052 "A11/U17
  never composes" — both verified pre-existing at base); scenarios
  sc_011 A6 + sc_012 A1/A9 verified failing identically at base.
- commit: `029f6785` (fix/718-tdd-make-fails-unit-behaviors branch base)
- recorded: cycle 0, before any change

## Cycle 1: unit-kind behaviors route to the plain-function generator (bug #718)

- behavior: `GenerationPlanner.plan()` dispatches on the behavior id's
  kind encoding (`U<n>` = unit, per SpecParser) BEFORE the
  description-keyed entity/CRUD branches, planning `zfa tdd func <id>`
  + `build` (the #657/#660 plain-function surface) for every unit
  behavior. Non-unit ids (acceptance `A<n>`, legacy `B-*`/dashed
  `U-6`) keep description-keyed routing unchanged.
- tests:
  - `test/plugins/tdd/services/generation_planner_test.dart` — new
    bug-718 group: U-718a (CRUD-keyword prose on `U5` routes to
    `['tdd','func','U5']`, the issue repro), U-718b (entity prose on
    `U6` never reaches `entity create`+`wire`), U-718c (explicit target
    cannot pull `U7` onto the CRUD branch), U-718d (function verb kept
    in the step purpose), U-718e (acceptance/legacy/dashed ids keep
    description-keyed routing), U-718f (`isUnitBehaviorId` recognizes
    exactly the `U<n>` encoding). Bug-696 group re-pinned on non-unit
    ids (`B-005/6/7`) since `U*` ids no longer reach the CRUD branch;
    bug-657 U11 re-pinned on `B-003` for the same reason.
  - `test/plugins/tdd/make_command_test.dart` — new bug-718 group:
    end-to-end `zfa tdd make U5` through a fake zfa whose func step
    implements the subject; asserts exit 0 / `outcome=green`, the
    `tdd func` invocation happened, and NO `make <slug>` invocation
    ever ran.
  - `test/plugins/tdd/scenarios/sc_018_plan_run_loop_e2e_test.dart` —
    the real-pipeline loop e2e's stub-replacement assertion tightened
    to the functional marker (`throw UnimplementedError`): the func
    surface's documented contract replaces only the stub DECLARATION,
    so the gen stub's prose doc comment legitimately remains. Run-loop
    behavior unchanged: plan → run still reaches all-DONE, exit 0.
- red: `dart test test/plugins/tdd/services/generation_planner_test.dart
  --plain-name "U-718"` -> 5 failures, the repro being U-718a:
  `Expected: ['tdd', 'func', 'U5'] Actual: ['make', 'u5', '--no-entity']
  Which: at location [0] is 'make' instead of 'tdd'` — the exact issue
  #718 dispatch (slugified behavior id handed to `zfa make` as an
  entity name). And the end-to-end make repro (`make_command_test.dart`,
  `--preset=all`) failed with the issue's verbatim signature:
  `plan: 2 step(s)` / `target test exit: 1` / `zfa tdd make: target test
  still fails after generation (exit 1).` / `make: behavior=U5
  outcome=generation-error` — exit 1.
- green: unit-kind branch 0 at
  `lib/src/plugins/tdd/services/generation_planner.dart`
  (`isUnitBehaviorId` -> `_functionSurfacePlan`, shared with the #657
  function-intent branch). Re-run: planner 20/20 passed;
  `make_command_test.dart --preset=all` 24 passed / 2 failed (the two
  pre-existing base failures, unchanged); sc_018 real-pipeline e2e
  passed (5m22s, all-DONE exit 0); sc_021 composition e2e passed.
- refactor: none required — the dispatch is a single guarded branch
  delegating to the existing func-surface plan builder.
- deliberate mutant (mutation sampling, no mutation tool in profile):
  `_unitBehaviorId` pattern `^U\d+$` mutated to `^X\d+$` (the original
  bug replayed — unit dispatch disabled). Caught by 5 of 6 planner
  bug-718 tests (U-718e correctly unaffected — it pins non-unit
  routing, which the mutant does not change) AND by the end-to-end
  make repro (generation-error exit 1 again). Restored exactly;
  planner 20/20 and make 24/2-green re-confirmed after restore.
  1 mutant, 1 caught.
- commit: (this commit)
