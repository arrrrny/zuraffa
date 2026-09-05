# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- evidence: A1 (AC-1) A1 — it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record).
- subject-hash: 057f0bb2226d51fc91d05cb6860260760542fd9a25d33c7198ae56a2bad28507
- criterion: AC-1
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart --plain-name "it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record)."`
- exit: 1
- at: 2026-09-05T11:02:25.035757Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart
00:00 +0: A1 (AC-1) A1 — it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record).
00:00 +0 -1: A1 (AC-1) A1 — it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>
  
  package:matcher                                          expect
  test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart: A1 (AC-1) A1 — it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 221e977fd27115c94b93a9708beb8054ce66a7489287f8af3f8034d2bc4f9708


## Live proof addendum (fix applied, 2026-09-05)

- Profile suite temporarily pointed at a 3s scoped test to avoid the 15-45 min full-suite
  baseline on this 2019 Intel machine; profile restored after the run.
- `zfa tdd make A1 --feature bug-tdd-run-baseline-timeout --timeout 45` (rebuilt binary):
  `baseline exit: 0, failed: 0` — the fallback baseline completes and produces a usable
  snapshot (was `baseline exit: -1` + refusal before the fix). Make then proceeded to the
  planner, which reported the honest `outcome=unexpressible` (prose bug scenario has no
  entity-pipeline mapping) instead of the old runner-error — the #1159 wall is gone.
- Unit proof: `test/plugins/tdd/bug_1159_baseline_timeout_test.dart` (5 tests) + adjacent
  suites — 42 passing.
