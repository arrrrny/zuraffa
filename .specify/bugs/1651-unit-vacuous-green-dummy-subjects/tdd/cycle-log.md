# Cycle Log: bug #1651 — the engine lane certifies vacuous greens over
# func-scaffolded dummy subjects

Append only. Newest last. Every entry's RED block is evidence that the
test existed and failed before the implementation landed on the branch.

## Baseline

- suite: full fast-tier chunked (`tools/run_tests_chunked.sh` semantics,
  104 folder chunks) + the TDD loose-file tier (226 files under
  `test/plugins/tdd/` + `test/plugins/tdd/services/`, run in 29 groups
  with kernel-cache cleanup) — all green on the branch base `66103851`
  except the pre-existing classes documented under Cycle 3.
- base commit: `66103851` (post-#1626 master state, spec-kit integration
  metadata).
- recorded: cycle 0, before any change.

## Cycle 1: the unit test generator derives the scenario's concrete
## values (remediation 1)

- behavior: `zfa tdd gen U1` for a declared contract whose spec scenario
  carries concrete values (`Given the integers 2 and 3 ... Then the sum
  5 is returned`) emits `subject_u1(2, 3)` + `expect(result, equals(5))`
  — never the scaffold representatives `(0, 0)` + `isA<int>()`
  (`test/plugins/tdd/commands/bug_1651_vacuous_green_e2e_test.dart` U1).
- RED (pre-fix tree, base `66103851` + the e2e suite copied in verbatim):
  `dart test test/plugins/tdd/commands/bug_1651_vacuous_green_e2e_test.dart`
  → `+1 -3`:
  - U1 RED — the generated test does not contain `(2, 3)`: the actual
    content is the post-#1259 scaffold shape
    (`subject.subject_u1(0, 0)` + `expect(result, isA<int>())`).
  - U2 RED — the func dummy PASSES the generated test (exit 0,
    `+1: All tests passed!` inside the fixture): the assertion does not
    discriminate.
  - U3 RED — `zfa tdd make` certifies the placeholder green (exit 0,
    `target test already passes — skipping generation`) with no
    vacuous-green refusal.
  - U4 green on the pre-fix tree (real implementations always certified
    — unchanged by the fix).
- GREEN (fix branch):
  `dart test test/plugins/tdd/commands/bug_1651_vacuous_green_e2e_test.dart
  test/plugins/tdd/bug_1651_scenario_assertions_test.dart
  test/plugins/tdd/services/scenario_example_1651_test.dart` → `+21: All
  tests passed!` (AC1/AC2 green; the writer/acceptance-isolation pins
  green; the parser/resolver unit tier green).
- implementation: `spec_parser.dart` scenario-example walk,
  `scenario_example.dart` (value model + resolver),
  `behavior_test_writer.dart` scenario branch (expected literal +
  argument claim, legacy byte-identical fallback),
  `gen_command.dart` scenario resolution (fail-open).

## Cycle 2: the vacuous-green gate refuses placeholder bodies (remediations
## 2 + 3) and the driver stop names the placeholder remedy

- behavior: a unit pair whose subject body is a scalar dummy
  (`return 0;`) and whose assertion set is type-only cannot certify
  green — `make` refuses with `outcome=vacuous-green` (exit 1, no green
  evidence appended), and the run driver's stop prints the placeholder
  remedy while preserving the `stopped_at=<id>:make` machine contract
  (e2e U3 + `bug_1651_driver_remedy_test.dart` U5 over the REAL
  `RunDriverCore` with the scripted fake zfa binary).
- RED: covered by the same pre-fix run — U3 RED above is the make
  certification of exactly this state (the cycle-1 scaffold pair IS the
  dummy+type-only class).
- GREEN (fix branch):
  `dart test --preset=all test/plugins/tdd/bug_1259_vacuous_green_test.dart
  test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart
  test/plugins/tdd/commands/bug_1651_driver_remedy_test.dart` → the
  1651 driver pin and the 1626 d1-d3 arms pass; U4 (real implementation
  + discriminating test) still certifies green unchanged (`+21` e2e run
  and `+12` bug_1320 batch).
- implementation: `scalar_dummy_subject.dart` (dummy-body detector +
  single-sourced remedy + the ONE gate decision predicate),
  `vacuous_guard.dart` `contentIsTypeOnlyAssertion` (value-matcher
  classification incl. the declared-boolean pins),
  `make_command.dart` step 9b, `run_driver_core.dart` placeholder arm.

## Cycle 3: the #1310 reconciliation — the declared floor

- behavior: the #1310 dead-end removal (plan_traces_cell_1310 U6) MUST
  keep certifying the declared-routed pair whose spec scenario carries
  NO derivable value (`create(String title) -> bool`, `isA<bool>()`,
  dummy `=> false;`). The first gate cut refused it — caught by the
  regression run, reconciled before commit.
- RED (intermediate state of THIS branch, real run):
  `dart test .../plan_traces_cell_1310_test.dart ...` → U6 `Expected: <0>
  Actual: <1>` — make refused with `outcome=vacuous-green` (the gate's
  false positive).
- GREEN (reconciled gate — `scalarDummyGreenMustRefuse` exempts the
  declared-routed pair whose scenario yields no derivable outcome
  literal): the same suite → `+24: All tests passed!` (U6 certifies; the
  #1651 refusal class still refuses — the detector pins U7/U8 pin both
  sides). AC3's fixture (criterion-only traces, no spec) still refuses.
- regression confirmation for the touched surfaces:
  - `test/plugins/tdd/commands` — 104 files in 11 groups → 687 tests,
    0 failures.
  - `test/plugins/tdd` + `test/plugins/tdd/services` loose tier — 226
    files in 29 groups → all green except the PRE-EXISTING classes:
    `bug_1259_vacuous_green_test.dart` U4/U5/U6 (they read
    `lib/tdd/090-tdd-fixture/` fixture residue that was never committed)
    and `make_command_test.dart` (10 failures — the #1587 build-skip vs
    the #942/#1530 build-guard pins). Both sets verified BYTE-IDENTICAL
    on a pristine `66103851` worktree before the fix — zero regressions
    from this change.
  - remaining fast-tier folders (agent..zap, 104 chunks) — all green.
