# RED evidence: BUG 1511 — bug 657 assertion drift

- **Date**: 2026-09-12
- **Branch**: `fix/1511-unexpressible-message-drift` (fix applied AFTER this capture;
  capture is from baseline `master` @ `03cdf45b` state of the test file)
- **Command**:
  `dart test --preset=all test/plugins/tdd/make_command_test.dart -n "bug 657"`
- **Exit code**: 1

## Raw failure output (verbatim)

```
00:00 +0: loading test/plugins/tdd/make_command_test.dart
00:00 +0: US4 — misfire-stop on unexpressible behaviors bug 657: an unexpressible make names the verb and the stub path with the manual-implementation hint ("implement manually at <stub_path>, then re-run")
00:08 +0 -1: US4 — misfire-stop on unexpressible behaviors bug 657: an unexpressible make names the verb and the stub path with the manual-implementation hint ("implement manually at <stub_path>, then re-run") [E]
  Expected: contains 'no generator for \'provision\''
    Actual: 'zfa tdd make: behavior B-042\n'
              '   feature: 090-tdd-fixture\n'
              '   test: test/b_042_test.dart\n'
              '   suite baseline: dart test\n'
              '   baseline exit: 1, failed: 1\n'
              '   note: test list unreadable ( no test list at /tmp/tdd_fixture_ULRGLD/specs/090-tdd-fixture/tdd/test-list.md — run `zfa tdd plan <feature>` first) — routing on id/description only\n'
              '   composition fallback disengaged: no test list at /tmp/tdd_fixture_ULRGLD/specs/090-tdd-fixture/tdd/test-list.md — run `zfa tdd plan <feature>` first\n'
              'zfa tdd make: cannot plan a generation for behavior "B-042". behavior "B-042" requires an implementation the zuraffa generation pipeline cannot express: no generator surface maps the behavior description "provision bespoke DSL syntax with no generator surface" to a `zfa entity create` / `zfa make` / `zfa build` invocation. File a zuraffa gap per the STOP-ON-ROADBLOCK policy.\n'
              'make: behavior=B-042 outcome=unexpressible feature=090-tdd-fixture\n'
              ''
     Which: does not contain 'no generator for \'provision\''

  package:matcher                                expect
  test/plugins/tdd/make_command_test.dart 955:7  main.<fn>.<fn>

00:08 +0 -1: US4 — misfire-stop on unexpressible behaviors bug 657: a render-type behavior plans the `tdd func` step through the pipeline (no longer unexpressible)
00:18 +1 -1: Some tests failed.

Failing tests:
  test/plugins/tdd/make_command_test.dart: US4 — misfire-stop on unexpressible behaviors bug 657: an unexpressible make names the verb and the stub path with the manual-implementation hint ("implement manually at <stub_path>, then re-run")
```

## Reading of the evidence

- The failure is exactly the reported drift: the test asserts the stale
  `no generator for 'provision'` substring while the command now emits the
  behavior-phrased refusal naming the full description and the STOP-ON-ROADBLOCK
  policy.
- The outcome/exit contract in the same output is intact
  (`make: behavior=B-042 outcome=unexpressible feature=090-tdd-fixture`), which is
  why the fix is correctly scoped to the assertions only.
- T2 (render-type green path) passed in the same run (`+1`), confirming the drift is
  isolated to T1's assertions.
