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
## Cycle: A1 (green)

- behavior: A1
- kind: green
- evidence: issue #1162 re-certification — the subject was hand-implemented after the certified red; this green evidence binds the NEW subject shape with the passing transcript
- subject-hash: d833feb13f1b4a84f8cca73de9a9aaf153e9258083220452cab05dc1224f9f6a
- criterion: AC-1
- test: test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart
- command: `dart test /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart --plain-name "it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record)." --preset=all`
- exit: 0
- at: 2026-09-06T07:04:06.113586Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart                                                                                                        00:01 +0: loading /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart                                                                                                        00:01 +0: A1 (AC-1) A1 — it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record).                                                                                     00:01 +1: A1 (AC-1) A1 — it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record).                                                                                     00:01 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 221e977fd27115c94b93a9708beb8054ce66a7489287f8af3f8034d2bc4f9708
- hash: 8798a577996edc3efbb20335ab59affb9037fc9bfc6b993b3f4358341b29ad7f

## Cycle: A1 (green)

- behavior: A1
- kind: green
- subject-hash: d833feb13f1b4a84f8cca73de9a9aaf153e9258083220452cab05dc1224f9f6a
- criterion: AC-1
- test: test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart
- command: `dart test /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart --plain-name "it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record)." --preset=all`
- exit: 0
- at: 2026-09-06T07:04:28.692693Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a1_test.dart                                                                                                        00:00 +0: A1 (AC-1) A1 — it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record).                                                                                     00:00 +1: A1 (AC-1) A1 — it completes and a parseable baseline snapshot is cached (not a `timedOut: true` record).                                                                                     00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 8798a577996edc3efbb20335ab59affb9037fc9bfc6b993b3f4358341b29ad7f
- hash: 1e4ecc5659743abfff51c2816711ea697843b38930fb7a8003e11678170c7373

## Cycle: A2 (red)

- behavior: A2
- kind: red
- classification: assertionFailure
- subject-hash: 248f80722eb131f7fa8f73ba0009ebaa710d18639ef6dbfbdbb8cbe8512a6e24
- criterion: AC-2
- test: /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a2_test.dart
- command: `dart test /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a2_test.dart --plain-name "the default 10-minute deadline still applies (no behavior change for small repos)." --preset=all`
- exit: 1
- at: 2026-09-06T07:05:20.790526Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a2_test.dart                                                                                                        00:00 +0: A2 (AC-2) A2 — the default 10-minute deadline still applies (no behavior change for small repos).                                                                                            00:00 +0 -1: A2 (AC-2) A2 — the default 10-minute deadline still applies (no behavior change for small repos). [E]                                                                                     
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a2 not implemented>
  
  package:matcher                                          expect
  test/tdd/bug-tdd-run-baseline-timeout/a2_test.dart 30:7  main.<fn>.<fn>
  

To run this test again: dart test /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a2_test.dart -p vm --plain-name 'A2 (AC-2) A2 — the default 10-minute deadline still applies (no behavior change for small repos).'
00:00 +0 -1: Some tests failed.                                                                                                                                                                        

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 2098722f42675d053b75d9c5e35f094e225ddc0f41e2a16ebd34ef8adb41bdee

## Cycle: A2 (green)

- behavior: A2
- kind: green
- subject-hash: 244c0533a645f3e46bc02f67919cd38bba6608d97532af5b2e964e1d04ac57d4
- criterion: AC-2
- test: /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a2_test.dart
- command: `dart test /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a2_test.dart --plain-name "the default 10-minute deadline still applies (no behavior change for small repos)." --preset=all`
- exit: 0
- at: 2026-09-06T07:06:31.323850Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a2_test.dart                                                                                                        00:00 +0: A2 (AC-2) A2 — the default 10-minute deadline still applies (no behavior change for small repos).                                                                                            00:00 +1: A2 (AC-2) A2 — the default 10-minute deadline still applies (no behavior change for small repos).                                                                                            00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 2098722f42675d053b75d9c5e35f094e225ddc0f41e2a16ebd34ef8adb41bdee
- hash: 9cc312822344aa2294105917be7f00fa8e89faf38eb163e7cf7df26b9f1114ac

## Cycle: A3 (red)

- behavior: A3
- kind: red
- classification: assertionFailure
- subject-hash: afb6395c04440880bddf79706a9a86a0f2212c8811a13172a2f95496578f9147
- criterion: AC-1
- test: /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a3_test.dart
- command: `dart test /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a3_test.dart --plain-name "it is allowed up to N and produces a usable snapshot." --preset=all`
- exit: 1
- at: 2026-09-06T07:07:46.190759Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a3_test.dart                                                                                                        00:00 +0: A3 (AC-1) A3 — it is allowed up to N and produces a usable snapshot.                                                                                                                         00:00 +0 -1: A3 (AC-1) A3 — it is allowed up to N and produces a usable snapshot. [E]                                                                                                                  
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a3 not implemented>
  
  package:matcher                                          expect
  test/tdd/bug-tdd-run-baseline-timeout/a3_test.dart 30:7  main.<fn>.<fn>
  

To run this test again: dart test /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a3_test.dart -p vm --plain-name 'A3 (AC-1) A3 — it is allowed up to N and produces a usable snapshot.'
00:00 +0 -1: Some tests failed.                                                                                                                                                                        

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 0415c8c42cc5d9e253d4e4d4653eb0734c0849e08c78a66b4073b5eeb710d5cd

## Cycle: A3 (green)

- behavior: A3
- kind: green
- subject-hash: cc17513d6cb88c8fe253f7cafc9f5e0d890a0af1744180e342e5ac989554f732
- criterion: AC-1
- test: /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a3_test.dart
- command: `dart test /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a3_test.dart --plain-name "it is allowed up to N and produces a usable snapshot." --preset=all`
- exit: 0
- at: 2026-09-06T07:09:16.942405Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/a3_test.dart                                                                                                        00:00 +0: A3 (AC-1) A3 — it is allowed up to N and produces a usable snapshot.                                                                                                                         00:00 +1: A3 (AC-1) A3 — it is allowed up to N and produces a usable snapshot.                                                                                                                         00:00 +1: All tests passed!
```
- generation:
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart tdd compose A3 --feature bug-tdd-run-baseline-timeout
    exit: 0
    purpose: compose subject of behavior A3 against 1 stub-only unit subject(s)
  - step: /home/z/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zfa.dart build
    exit: 0
    purpose: build composed code for behavior A3
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 0415c8c42cc5d9e253d4e4d4653eb0734c0849e08c78a66b4073b5eeb710d5cd
- hash: b5ddc80f8aafe34584ec9758afcda9ec6efc93c5b2d833d6c004c13e047caed7

## Cycle: U1 (red)

- behavior: U1
- kind: red
- classification: assertionFailure
- subject-hash: 3926706b7ef5425527bced4aa6cd22e6b2d809f311af14ab61ba7c5cf267dec4
- criterion: FR-001
- test: /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/u1_test.dart
- command: `dart test /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/u1_test.dart --plain-name "The TDD driver MUST forward its `--timeout` override to the run-level suite baseline process." --preset=all`
- exit: 1
- at: 2026-09-06T07:15:41.888363Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/u1_test.dart                                                                                                        00:00 +0: U1 (FR-001) U1 — The TDD driver MUST forward its `--timeout` override to the run-level suite baseline process.                                                                               00:00 +0 -1: U1 (FR-001) U1 — The TDD driver MUST forward its `--timeout` override to the run-level suite baseline process. [E]                                                                        
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u1 not implemented>
  
  package:matcher                                          expect
  test/tdd/bug-tdd-run-baseline-timeout/u1_test.dart 29:7  main.<fn>.<fn>
  

To run this test again: dart test /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/u1_test.dart -p vm --plain-name 'U1 (FR-001) U1 — The TDD driver MUST forward its `--timeout` override to the run-level suite baseline process.'
00:00 +0 -1: Some tests failed.                                                                                                                                                                        

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: eec6c8eebb3a0b4a717092b6fde1d72adb42cb327a7b53d34d144cf8d14dbde3

## Cycle: U1 (green)

- behavior: U1
- kind: green
- subject-hash: 5ffdc37ef046e7c0509cc8f12da63dd93f36e2ef14639baafe0ce2f28942b90a
- criterion: FR-001
- test: /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/u1_test.dart
- command: `dart test /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/u1_test.dart --plain-name "The TDD driver MUST forward its `--timeout` override to the run-level suite baseline process." --preset=all`
- exit: 0
- at: 2026-09-06T07:18:55.932551Z
- output:
```
00:00 +0: loading /home/z/my-project/zuraffa/test/tdd/bug-tdd-run-baseline-timeout/u1_test.dart                                                                                                        00:00 +0: U1 (FR-001) U1 — The TDD driver MUST forward its `--timeout` override to the run-level suite baseline process.                                                                               00:00 +1: U1 (FR-001) U1 — The TDD driver MUST forward its `--timeout` override to the run-level suite baseline process.                                                                               00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: eec6c8eebb3a0b4a717092b6fde1d72adb42cb327a7b53d34d144cf8d14dbde3
- hash: 54964792704034fd284d231e1c031488492fc2df01b4af343ae92fcce021d5a5

