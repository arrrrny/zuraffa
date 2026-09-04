# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: A2 (red)

- behavior: A2
- kind: red
- classification: assertionFailure
- evidence: A2 (AC-2) A2 — it is green — no test references the host.
- criterion: AC-2
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a2_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a2_test.dart --plain-name "it is green — no test references the host."`
- exit: 1
- at: 2026-09-04T04:06:27.996757Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a2_test.dart
00:00 +0: A2 (AC-2) A2 — it is green — no test references the host.
00:00 +0 -1: A2 (AC-2) A2 — it is green — no test references the host. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a2 not implemented>
  
  package:matcher                                 expect
  test/tdd/073-slice-isolation/a2_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a2_test.dart: A2 (AC-2) A2 — it is green — no test references the host.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 8002d735267cf7e315631272e3c6cb48e77c5c6f8ac0c69aaeb02dba1f6d1c10

## Cycle: A4 (red)

- behavior: A4
- kind: red
- classification: assertionFailure
- evidence: A4 (AC-4) A4 — the certified channel fake from the tdd plugin is installed in the sandbox's DI.
- criterion: AC-4
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a4_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a4_test.dart --plain-name "the certified channel fake from the tdd plugin is installed in the sandbox's DI."`
- exit: 1
- at: 2026-09-04T04:07:58.102913Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a4_test.dart
00:00 +0: A4 (AC-4) A4 — the certified channel fake from the tdd plugin is installed in the sandbox's DI.
00:00 +0 -1: A4 (AC-4) A4 — the certified channel fake from the tdd plugin is installed in the sandbox's DI. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a4 not implemented>
  
  package:matcher                                 expect
  test/tdd/073-slice-isolation/a4_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a4_test.dart: A4 (AC-4) A4 — the certified channel fake from the tdd plugin is installed in the sandbox's DI.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: c74383b3fc25be468826cbd0aa46bb3cd90e8b119069d32c2dc3b8ad66143edc

## Cycle: A5 (red)

- behavior: A5
- kind: red
- classification: assertionFailure
- evidence: A5 (AC-5) A5 — the sandbox's generated wiring is byte-for-byte identical (deterministic scaffolding).
- criterion: AC-5
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a5_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a5_test.dart --plain-name "the sandbox's generated wiring is byte-for-byte identical (deterministic scaffolding)."`
- exit: 1
- at: 2026-09-04T04:09:11.173810Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a5_test.dart
00:00 +0: A5 (AC-5) A5 — the sandbox's generated wiring is byte-for-byte identical (deterministic scaffolding).
00:00 +0 -1: A5 (AC-5) A5 — the sandbox's generated wiring is byte-for-byte identical (deterministic scaffolding). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a5 not implemented>
  
  package:matcher                                 expect
  test/tdd/073-slice-isolation/a5_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a5_test.dart: A5 (AC-5) A5 — the sandbox's generated wiring is byte-for-byte identical (deterministic scaffolding).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: b805b889a779138e4adc3b83acf827940c119e8b59560d2b39f8319147bea279

## Cycle: A6 (red)

- behavior: A6
- kind: red
- classification: assertionFailure
- evidence: A6 (AC-6) A6 — the loop completes its cycle over those behaviors (red certified, green landed) with no reference to the host.
- criterion: AC-6
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a6_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a6_test.dart --plain-name "the loop completes its cycle over those behaviors (red certified, green landed) with no reference to the host."`
- exit: 1
- at: 2026-09-04T04:10:22.012829Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a6_test.dart
00:00 +0: A6 (AC-6) A6 — the loop completes its cycle over those behaviors (red certified, green landed) with no reference to the host.
00:00 +0 -1: A6 (AC-6) A6 — the loop completes its cycle over those behaviors (red certified, green landed) with no reference to the host. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a6 not implemented>
  
  package:matcher                                 expect
  test/tdd/073-slice-isolation/a6_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a6_test.dart: A6 (AC-6) A6 — the loop completes its cycle over those behaviors (red certified, green landed) with no reference to the host.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: cba066e6c87924f2be0cf8921c3aba8a0bc814455a89a4f2b098ddd9bde9da0d

## Cycle: A7 (red)

- behavior: A7
- kind: red
- classification: assertionFailure
- evidence: A7 (AC-7) A7 — they contain the run's evidence (reds certified, greens, artifacts) — the receipts live in the sandbox, not the host.
- criterion: AC-7
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a7_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a7_test.dart --plain-name "they contain the run's evidence (reds certified, greens, artifacts) — the receipts live in the sandbox, not the host."`
- exit: 1
- at: 2026-09-04T04:11:32.629532Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a7_test.dart
00:00 +0: A7 (AC-7) A7 — they contain the run's evidence (reds certified, greens, artifacts) — the receipts live in the sandbox, not the host.
00:00 +0 -1: A7 (AC-7) A7 — they contain the run's evidence (reds certified, greens, artifacts) — the receipts live in the sandbox, not the host. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a7 not implemented>
  
  package:matcher                                 expect
  test/tdd/073-slice-isolation/a7_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a7_test.dart: A7 (AC-7) A7 — they contain the run's evidence (reds certified, greens, artifacts) — the receipts live in the sandbox, not the host.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 4ca8986ce2f0a0b13bd90f0f8a2640ec8c86e3040b85a0e163cd3b8329afb733

## Cycle: A8 (red)

- behavior: A8
- kind: red
- classification: assertionFailure
- evidence: A8 (AC-8) A8 — every step succeeds without host knowledge.
- criterion: AC-8
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a8_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a8_test.dart --plain-name "every step succeeds without host knowledge."`
- exit: 1
- at: 2026-09-04T04:12:43.106265Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a8_test.dart
00:00 +0: A8 (AC-8) A8 — every step succeeds without host knowledge.
00:00 +0 -1: A8 (AC-8) A8 — every step succeeds without host knowledge. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a8 not implemented>
  
  package:matcher                                 expect
  test/tdd/073-slice-isolation/a8_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a8_test.dart: A8 (AC-8) A8 — every step succeeds without host knowledge.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: d8301edd23c52d6ed93a5854154b1d84f56135a949e4dcbd1d80b1e5023b07ba

## Cycle: A9 (red)

- behavior: A9
- kind: red
- classification: assertionFailure
- evidence: A9 (AC-9) A9 — it exits 0 and the JSON verdict reports self-containment, mock certification, and suite state as passing.
- criterion: AC-9
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a9_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a9_test.dart --plain-name "it exits 0 and the JSON verdict reports self-containment, mock certification, and suite state as passing."`
- exit: 1
- at: 2026-09-04T04:13:52.762429Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a9_test.dart
00:00 +0: A9 (AC-9) A9 — it exits 0 and the JSON verdict reports self-containment, mock certification, and suite state as passing.
00:00 +0 -1: A9 (AC-9) A9 — it exits 0 and the JSON verdict reports self-containment, mock certification, and suite state as passing. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a9 not implemented>
  
  package:matcher                                 expect
  test/tdd/073-slice-isolation/a9_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a9_test.dart: A9 (AC-9) A9 — it exits 0 and the JSON verdict reports self-containment, mock certification, and suite state as passing.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 86e04a05ba75b8c1feacb14092227a1bd7ff40d4a90c1a7b30841b79e9a17751

## Cycle: A10 (red)

- behavior: A10
- kind: red
- classification: assertionFailure
- evidence: A10 (AC-10) A10 — it exits non-zero, its verdict marks self-containment failed, and the offending reference is named.
- criterion: AC-10
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a10_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a10_test.dart --plain-name "it exits non-zero, its verdict marks self-containment failed, and the offending reference is named."`
- exit: 1
- at: 2026-09-04T04:15:02.662123Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a10_test.dart
00:00 +0: A10 (AC-10) A10 — it exits non-zero, its verdict marks self-containment failed, and the offending reference is named.
00:00 +0 -1: A10 (AC-10) A10 — it exits non-zero, its verdict marks self-containment failed, and the offending reference is named. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a10 not implemented>
  
  package:matcher                                  expect
  test/tdd/073-slice-isolation/a10_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a10_test.dart: A10 (AC-10) A10 — it exits non-zero, its verdict marks self-containment failed, and the offending reference is named.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: f78d47b2d37aec201fabc2808b9e83f8a4190872570f89f581cf8925958d3ee0

## Cycle: A11 (red)

- behavior: A11
- kind: red
- classification: assertionFailure
- evidence: A11 (AC-11) A11 — mock certification fails naming the unbound dependency.
- criterion: AC-11
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a11_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a11_test.dart --plain-name "mock certification fails naming the unbound dependency."`
- exit: 1
- at: 2026-09-04T04:16:12.715369Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a11_test.dart
00:00 +0: A11 (AC-11) A11 — mock certification fails naming the unbound dependency.
00:00 +0 -1: A11 (AC-11) A11 — mock certification fails naming the unbound dependency. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a11 not implemented>
  
  package:matcher                                  expect
  test/tdd/073-slice-isolation/a11_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a11_test.dart: A11 (AC-11) A11 — mock certification fails naming the unbound dependency.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 3de03a3e32b95c51209e2062eb47d1a49e60a4933b82affb266f8f5a7e72c59d

## Cycle: A12 (red)

- behavior: A12
- kind: red
- classification: assertionFailure
- evidence: A12 (AC-12) A12 — the feature's artifacts, journal, and registry land in the host.
- criterion: AC-12
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a12_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a12_test.dart --plain-name "the feature's artifacts, journal, and registry land in the host."`
- exit: 1
- at: 2026-09-04T04:17:24.058706Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a12_test.dart
00:00 +0: A12 (AC-12) A12 — the feature's artifacts, journal, and registry land in the host.
00:00 +0 -1: A12 (AC-12) A12 — the feature's artifacts, journal, and registry land in the host. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a12 not implemented>
  
  package:matcher                                  expect
  test/tdd/073-slice-isolation/a12_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a12_test.dart: A12 (AC-12) A12 — the feature's artifacts, journal, and registry land in the host.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 9996d563e87112aa0044629252c18a6d015e4501eb6358a432567631f6e70508

## Cycle: A13 (red)

- behavior: A13
- kind: red
- classification: assertionFailure
- evidence: A13 (AC-13) A13 — it is green.
- criterion: AC-13
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a13_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a13_test.dart --plain-name "it is green."`
- exit: 1
- at: 2026-09-04T04:18:33.950511Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a13_test.dart
00:00 +0: A13 (AC-13) A13 — it is green.
00:00 +0 -1: A13 (AC-13) A13 — it is green. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a13 not implemented>
  
  package:matcher                                  expect
  test/tdd/073-slice-isolation/a13_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a13_test.dart: A13 (AC-13) A13 — it is green.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 61fe611e33339057df0cae48747bf30e8c783fdcc6ec4e7348add6870fe94411

## Cycle: A14 (red)

- behavior: A14
- kind: red
- classification: assertionFailure
- evidence: A14 (AC-14) A14 — it refuses naming the failed check (merge requires a verified slice).
- criterion: AC-14
- test: /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a14_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a14_test.dart --plain-name "it refuses naming the failed check (merge requires a verified slice)."`
- exit: 1
- at: 2026-09-04T04:19:43.415506Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a14_test.dart
00:00 +0: A14 (AC-14) A14 — it refuses naming the failed check (merge requires a verified slice).
00:00 +0 -1: A14 (AC-14) A14 — it refuses naming the failed check (merge requires a verified slice). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a14 not implemented>
  
  package:matcher                                  expect
  test/tdd/073-slice-isolation/a14_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a14_test.dart: A14 (AC-14) A14 — it refuses naming the failed check (merge requires a verified slice).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 73e79bc7ee58dcf680f469fabb01e27bb427524a03c39606d8f4bbf97f2f891c

