# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- evidence: A1 (AC-1) A1 — the generated interface exposes `signIn(email, password) -> User` and `signOut() -> void` with no additional, missing, or renamed members.
- criterion: AC-1
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a1_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a1_test.dart --plain-name "the generated interface exposes `signIn(email, password) -> User` and `signOut() -> void` with no additional, missing, or renamed members."`
- exit: 1
- at: 2026-09-04T00:04:53.044414Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a1_test.dart
00:00 +0: A1 (AC-1) A1 — the generated interface exposes `signIn(email, password) -> User` and `signOut() -> void` with no additional, missing, or renamed members.
00:00 +0 -1: A1 (AC-1) A1 — the generated interface exposes `signIn(email, password) -> User` and `signOut() -> void` with no additional, missing, or renamed members. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/a1_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a1_test.dart: A1 (AC-1) A1 — the generated interface exposes `signIn(email, password) -> User` and `signOut() -> void` with no additional, missing, or renamed members.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 07fdb82eb0b428deddb4b164d9c488b2e8bdc3cd34ca1cbd3e60cb42f903a209

## Cycle: A2 (red)

- behavior: A2
- kind: red
- classification: assertionFailure
- evidence: A2 (AC-2) A2 — the fake returns exactly the scripted value and records the call (arguments and order) for later assertion.
- criterion: AC-2
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a2_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a2_test.dart --plain-name "the fake returns exactly the scripted value and records the call (arguments and order) for later assertion."`
- exit: 1
- at: 2026-09-04T01:14:51.854205Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a2_test.dart
00:00 +0: A2 (AC-2) A2 — the fake returns exactly the scripted value and records the call (arguments and order) for later assertion.
00:00 +0 -1: A2 (AC-2) A2 — the fake returns exactly the scripted value and records the call (arguments and order) for later assertion. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a2 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/a2_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a2_test.dart: A2 (AC-2) A2 — the fake returns exactly the scripted value and records the call (arguments and order) for later assertion.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 73384a483e29ccd5dbc7fede618e5afed2f46c2aadcfd008f0149593e5aae435

## Cycle: A2 (green)

- behavior: A2
- kind: green
- criterion: AC-2
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a2_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a2_test.dart --plain-name "the fake returns exactly the scripted value and records the call (arguments and order) for later assertion."`
- exit: 0
- at: 2026-09-04T01:17:17.854674Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a2_test.dart
00:00 +0: A2 (AC-2) A2 — the fake returns exactly the scripted value and records the call (arguments and order) for later assertion.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd func A2 --feature 072-dependency-mocks
    exit: 0
    purpose: scaffold the return function for behavior A2 from its description
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build generated code for behavior A2
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 73384a483e29ccd5dbc7fede618e5afed2f46c2aadcfd008f0149593e5aae435
- hash: 3cafef590576729933f34e4b0238b9289003ef1c9063dc84f234d0a751ed5437

## Cycle: A3 (red)

- behavior: A3
- kind: red
- classification: assertionFailure
- evidence: A3 (AC-3) A3 — the generated artifacts are byte-for-byte identical.
- criterion: AC-3
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a3_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a3_test.dart --plain-name "the generated artifacts are byte-for-byte identical."`
- exit: 1
- at: 2026-09-04T01:18:06.965369Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a3_test.dart
00:00 +0: A3 (AC-3) A3 — the generated artifacts are byte-for-byte identical.
00:00 +0 -1: A3 (AC-3) A3 — the generated artifacts are byte-for-byte identical. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a3 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/a3_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a3_test.dart: A3 (AC-3) A3 — the generated artifacts are byte-for-byte identical.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: b4bcce074d03a89c34c2886f9f7378b7b2744675c86446dfabd7caf8c6cadaa2

## Cycle: A4 (red)

- behavior: A4
- kind: red
- classification: assertionFailure
- evidence: A4 (AC-4) A4 — it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add.
- criterion: AC-4
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a4_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a4_test.dart --plain-name "it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add."`
- exit: 1
- at: 2026-09-04T01:19:20.922855Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a4_test.dart
00:00 +0: A4 (AC-4) A4 — it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add.
00:00 +0 -1: A4 (AC-4) A4 — it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a4 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/a4_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a4_test.dart: A4 (AC-4) A4 — it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 06b028056ba3e3440c4409cc4cf9219f1b06cb48380e87fc5ea72c4393f2644b

## Cycle: A5 (red)

- behavior: A5
- kind: red
- classification: assertionFailure
- evidence: A5 (AC-5) A5 — the generated mock conforms to the storage contract the row declares (the rail is dependency-kind-agnostic across the declared service and storage kinds).
- criterion: AC-5
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a5_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a5_test.dart --plain-name "the generated mock conforms to the storage contract the row declares (the rail is dependency-kind-agnostic across the declared service and storage kinds)."`
- exit: 1
- at: 2026-09-04T01:20:43.348467Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a5_test.dart
00:00 +0: A5 (AC-5) A5 — the generated mock conforms to the storage contract the row declares (the rail is dependency-kind-agnostic across the declared service and storage kinds).
00:00 +0 -1: A5 (AC-5) A5 — the generated mock conforms to the storage contract the row declares (the rail is dependency-kind-agnostic across the declared service and storage kinds). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a5 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/a5_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a5_test.dart: A5 (AC-5) A5 — the generated mock conforms to the storage contract the row declares (the rail is dependency-kind-agnostic across the declared service and storage kinds).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 736ac41a6f56f4c0542935c91652cd60d5c27a13672ec1ba15e3dfaaff4797da

## Cycle: A6 (red)

- behavior: A6
- kind: red
- classification: assertionFailure
- evidence: A6 (AC-6) A6 — the harness wires the generated `FirebaseAuth` mock and the behavior tests through it.
- criterion: AC-6
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a6_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a6_test.dart --plain-name "the harness wires the generated `FirebaseAuth` mock and the behavior tests through it."`
- exit: 1
- at: 2026-09-04T01:22:15.281723Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a6_test.dart
00:00 +0: A6 (AC-6) A6 — the harness wires the generated `FirebaseAuth` mock and the behavior tests through it.
00:00 +0 -1: A6 (AC-6) A6 — the harness wires the generated `FirebaseAuth` mock and the behavior tests through it. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a6 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/a6_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a6_test.dart: A6 (AC-6) A6 — the harness wires the generated `FirebaseAuth` mock and the behavior tests through it.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 54d21b4c113981fcb832259af839b35c1cfd6744bd7408861cf71a1726e2cf84

## Cycle: A7 (red)

- behavior: A7
- kind: red
- classification: assertionFailure
- evidence: A7 (AC-7) A7 — it names the dependency row (dependency name + contract) as the consulted declaration.
- criterion: AC-7
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a7_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a7_test.dart --plain-name "it names the dependency row (dependency name + contract) as the consulted declaration."`
- exit: 1
- at: 2026-09-04T01:23:30.616369Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a7_test.dart
00:00 +0: A7 (AC-7) A7 — it names the dependency row (dependency name + contract) as the consulted declaration.
00:00 +0 -1: A7 (AC-7) A7 — it names the dependency row (dependency name + contract) as the consulted declaration. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a7 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/a7_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a7_test.dart: A7 (AC-7) A7 — it names the dependency row (dependency name + contract) as the consulted declaration.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 96775db07d55c87c00b994890a89749b711cfcb77ee67c7283c9a50e87547811

## Cycle: A8 (red)

- behavior: A8
- kind: red
- classification: assertionFailure
- evidence: A8 (AC-8) A8 — the behavior is NOT routed to a dependency mock (no prose sniffing).
- criterion: AC-8
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a8_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a8_test.dart --plain-name "the behavior is NOT routed to a dependency mock (no prose sniffing)."`
- exit: 1
- at: 2026-09-04T01:24:42.630655Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a8_test.dart
00:00 +0: A8 (AC-8) A8 — the behavior is NOT routed to a dependency mock (no prose sniffing).
00:00 +0 -1: A8 (AC-8) A8 — the behavior is NOT routed to a dependency mock (no prose sniffing). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a8 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/a8_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a8_test.dart: A8 (AC-8) A8 — the behavior is NOT routed to a dependency mock (no prose sniffing).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 6e7db183c011b6e87c93313ed4b58ae7e3ea779fea3424cd45333c50cfbd128b

## Cycle: A9 (red)

- behavior: A9
- kind: red
- classification: assertionFailure
- evidence: A9 (AC-9) A9 — the run refuses (or auto-generates under the loop's existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double.
- criterion: AC-9
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a9_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a9_test.dart --plain-name "the run refuses (or auto-generates under the loop's existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double."`
- exit: 1
- at: 2026-09-04T01:25:53.130202Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a9_test.dart
00:00 +0: A9 (AC-9) A9 — the run refuses (or auto-generates under the loop's existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double.
00:00 +0 -1: A9 (AC-9) A9 — the run refuses (or auto-generates under the loop's existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a9 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/a9_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a9_test.dart: A9 (AC-9) A9 — the run refuses (or auto-generates under the loop's existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 22958d044d819fbe52da52563d254572b047f74a76c8c1d965849a334e8c828b

## Cycle: A10 (red)

- behavior: A10
- kind: red
- classification: assertionFailure
- evidence: A10 (AC-10) A10 — the materialization order is exactly P1, P2, P3, none.
- criterion: AC-10
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a10_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a10_test.dart --plain-name "the materialization order is exactly P1, P2, P3, none."`
- exit: 1
- at: 2026-09-04T01:27:05.707577Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a10_test.dart
00:00 +0: A10 (AC-10) A10 — the materialization order is exactly P1, P2, P3, none.
00:00 +0 -1: A10 (AC-10) A10 — the materialization order is exactly P1, P2, P3, none. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a10 not implemented>
  
  package:matcher                                   expect
  test/tdd/072-dependency-mocks/a10_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a10_test.dart: A10 (AC-10) A10 — the materialization order is exactly P1, P2, P3, none.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: de1d136660b22fb037155d4e04c8c64bb7834fda323d72191c376f5729660562

## Cycle: A11 (red)

- behavior: A11
- kind: red
- classification: assertionFailure
- evidence: A11 (AC-11) A11 — their relative order equals their declaration order in the spec, stably across runs.
- criterion: AC-11
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a11_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a11_test.dart --plain-name "their relative order equals their declaration order in the spec, stably across runs."`
- exit: 1
- at: 2026-09-04T01:28:22.125062Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a11_test.dart
00:00 +0: A11 (AC-11) A11 — their relative order equals their declaration order in the spec, stably across runs.
00:00 +0 -1: A11 (AC-11) A11 — their relative order equals their declaration order in the spec, stably across runs. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a11 not implemented>
  
  package:matcher                                   expect
  test/tdd/072-dependency-mocks/a11_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a11_test.dart: A11 (AC-11) A11 — their relative order equals their declaration order in the spec, stably across runs.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 8f6fa53794466321cbbcd6eee051cbec98ac091f473ce7563aa6ebfc82ef0eb4

## Cycle: A12 (red)

- behavior: A12
- kind: red
- classification: assertionFailure
- evidence: A12 (AC-12) A12 — each row's priority and resulting order position are visible.
- criterion: AC-12
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a12_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a12_test.dart --plain-name "each row's priority and resulting order position are visible."`
- exit: 1
- at: 2026-09-04T01:29:34.313308Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a12_test.dart
00:00 +0: A12 (AC-12) A12 — each row's priority and resulting order position are visible.
00:00 +0 -1: A12 (AC-12) A12 — each row's priority and resulting order position are visible. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a12 not implemented>
  
  package:matcher                                   expect
  test/tdd/072-dependency-mocks/a12_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a12_test.dart: A12 (AC-12) A12 — each row's priority and resulting order position are visible.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: b93e4ee3bb62734ee05e2f025f9e130c86f5de35c0f7ad14c948d29288d75dc1

## Cycle: A13 (red)

- behavior: A13
- kind: red
- classification: assertionFailure
- evidence: A13 (AC-13) A13 — the differential gates compare against the declared contract and the suite stays green through the swap.
- criterion: AC-13
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a13_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a13_test.dart --plain-name "the differential gates compare against the declared contract and the suite stays green through the swap."`
- exit: 1
- at: 2026-09-04T01:30:46.441147Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a13_test.dart
00:00 +0: A13 (AC-13) A13 — the differential gates compare against the declared contract and the suite stays green through the swap.
00:00 +0 -1: A13 (AC-13) A13 — the differential gates compare against the declared contract and the suite stays green through the swap. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a13 not implemented>
  
  package:matcher                                   expect
  test/tdd/072-dependency-mocks/a13_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a13_test.dart: A13 (AC-13) A13 — the differential gates compare against the declared contract and the suite stays green through the swap.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 03155df8ecfdc1915151e7c629dedeb3eaf62a78352502417da770b462995459

## Cycle: A14 (red)

- behavior: A14
- kind: red
- classification: assertionFailure
- evidence: A14 (AC-14) A14 — it refuses naming the missing method and the contract row — never silently swapping a drifting adapter.
- criterion: AC-14
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a14_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a14_test.dart --plain-name "it refuses naming the missing method and the contract row — never silently swapping a drifting adapter."`
- exit: 1
- at: 2026-09-04T01:32:15.300909Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a14_test.dart
00:00 +0: A14 (AC-14) A14 — it refuses naming the missing method and the contract row — never silently swapping a drifting adapter.
00:00 +0 -1: A14 (AC-14) A14 — it refuses naming the missing method and the contract row — never silently swapping a drifting adapter. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a14 not implemented>
  
  package:matcher                                   expect
  test/tdd/072-dependency-mocks/a14_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a14_test.dart: A14 (AC-14) A14 — it refuses naming the missing method and the contract row — never silently swapping a drifting adapter.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: bba768aaa9660f388592ef2734d3e30acf121d7ae91a0eabe843de3ee3461698

## Cycle: A15 (red)

- behavior: A15
- kind: red
- classification: assertionFailure
- evidence: A15 (AC-15) A15 — they run unchanged against the real adapter (same interface, same harness seam).
- criterion: AC-15
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a15_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a15_test.dart --plain-name "they run unchanged against the real adapter (same interface, same harness seam)."`
- exit: 1
- at: 2026-09-04T01:33:25.396152Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a15_test.dart
00:00 +0: A15 (AC-15) A15 — they run unchanged against the real adapter (same interface, same harness seam).
00:00 +0 -1: A15 (AC-15) A15 — they run unchanged against the real adapter (same interface, same harness seam). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a15 not implemented>
  
  package:matcher                                   expect
  test/tdd/072-dependency-mocks/a15_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a15_test.dart: A15 (AC-15) A15 — they run unchanged against the real adapter (same interface, same harness seam).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 47a725444edf23e1078344436b26f323934b5e9c935a62fddc39d55fc2c6fb16

## Cycle: U1 (red)

- behavior: U1
- kind: red
- classification: assertionFailure
- evidence: U1 (FR-001) U1 — The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared.
- criterion: FR-001
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u1_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u1_test.dart --plain-name "The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared."`
- exit: 1
- at: 2026-09-04T01:34:34.594975Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u1_test.dart
00:00 +0: U1 (FR-001) U1 — The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared.
00:00 +0 -1: U1 (FR-001) U1 — The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u1 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/u1_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u1_test.dart: U1 (FR-001) U1 — The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 829215543d605d33af6e3737972e2a2b59c5c95fb7a29f0aaf2f8ace2582730d

## Cycle: U1 (green)

- behavior: U1
- kind: green
- criterion: FR-001
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u1_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u1_test.dart --plain-name "The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared."`
- exit: 0
- at: 2026-09-04T01:35:49.031054Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u1_test.dart
00:00 +0: U1 (FR-001) U1 — The system MUST provide `zfa mock dependency <Name>`, which reads the declared External Dependencies & Contracts row for `<Name>` and refuses non-zero with the row to add when the name is undeclared.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd func U1 --feature 072-dependency-mocks
    exit: 0
    purpose: scaffold the plain-function function for behavior U1 from its description
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build generated code for behavior U1
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 829215543d605d33af6e3737972e2a2b59c5c95fb7a29f0aaf2f8ace2582730d
- hash: 3c19924211c07fff7a4e40c265fc129b2cd57cdf41879fb4171b6547dbb453c5

## Cycle: U2 (red)

- behavior: U2
- kind: red
- classification: assertionFailure
- evidence: U2 (FR-002) U2 — The generated mock package MUST expose exactly the declared contract's surface — method names, parameter lists, and return types as the row declares — with no invented, missing, or renamed members.
- criterion: FR-002
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u2_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u2_test.dart --plain-name "The generated mock package MUST expose exactly the declared contract's surface — method names, parameter lists, and return types as the row declares — with no invented, missing, or renamed members."`
- exit: 1
- at: 2026-09-04T01:36:35.338548Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u2_test.dart
00:00 +0: U2 (FR-002) U2 — The generated mock package MUST expose exactly the declared contract's surface — method names, parameter lists, and return types as the row declares — with no invented, missing, or renamed members.
00:00 +0 -1: U2 (FR-002) U2 — The generated mock package MUST expose exactly the declared contract's surface — method names, parameter lists, and return types as the row declares — with no invented, missing, or renamed members. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u2 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/u2_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u2_test.dart: U2 (FR-002) U2 — The generated mock package MUST expose exactly the declared contract's surface — method names, parameter lists, and return types as the row declares — with no invented, missing, or renamed members.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: e501d04c1db11d542cda07122cf5aaf79f3ccc24d09e14afa542953524458e70

## Cycle: U2 (green)

- behavior: U2
- kind: green
- criterion: FR-002
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u2_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u2_test.dart --plain-name "The generated mock package MUST expose exactly the declared contract's surface — method names, parameter lists, and return types as the row declares — with no invented, missing, or renamed members."`
- exit: 0
- at: 2026-09-04T01:37:46.863293Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u2_test.dart
00:00 +0: U2 (FR-002) U2 — The generated mock package MUST expose exactly the declared contract's surface — method names, parameter lists, and return types as the row declares — with no invented, missing, or renamed members.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd func U2 --feature 072-dependency-mocks
    exit: 0
    purpose: scaffold the return function for behavior U2 from its description
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build generated code for behavior U2
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: e501d04c1db11d542cda07122cf5aaf79f3ccc24d09e14afa542953524458e70
- hash: 21e77d2ef951bea3b8b94fcd2ab08bd2a8c09133a67da6c19f061b8e9e67ac80

## Cycle: U3 (red)

- behavior: U3
- kind: red
- classification: assertionFailure
- evidence: U3 (FR-003) U3 — The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions.
- criterion: FR-003
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u3_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u3_test.dart --plain-name "The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions."`
- exit: 1
- at: 2026-09-04T01:38:34.461185Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u3_test.dart
00:00 +0: U3 (FR-003) U3 — The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions.
00:00 +0 -1: U3 (FR-003) U3 — The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u3 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/u3_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u3_test.dart: U3 (FR-003) U3 — The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 5669544cc5b95202412a08e116a0c206206f606e27a60ba812df596ca20e8813

## Cycle: U3 (green)

- behavior: U3
- kind: green
- criterion: FR-003
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u3_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u3_test.dart --plain-name "The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions."`
- exit: 0
- at: 2026-09-04T01:39:47.968809Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u3_test.dart
00:00 +0: U3 (FR-003) U3 — The generated package MUST include a certified fake with scriptable per-method responses and call recording (arguments and invocation order) sufficient for tests to assert interactions.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd func U3 --feature 072-dependency-mocks
    exit: 0
    purpose: scaffold the plain-function function for behavior U3 from its description
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build generated code for behavior U3
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 5669544cc5b95202412a08e116a0c206206f606e27a60ba812df596ca20e8813
- hash: 746a181911ce4894da92ac809dde1405bfa150da00e2c721644b9d768be657ff

## Cycle: U4 (red)

- behavior: U4
- kind: red
- classification: assertionFailure
- evidence: U4 (FR-004) U4 — Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output.
- criterion: FR-004
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u4_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u4_test.dart --plain-name "Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output."`
- exit: 1
- at: 2026-09-04T01:40:35.592566Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u4_test.dart
00:00 +0: U4 (FR-004) U4 — Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output.
00:00 +0 -1: U4 (FR-004) U4 — Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u4 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/u4_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u4_test.dart: U4 (FR-004) U4 — Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: c71bc0b3d92811c1b68a5731089c5f125bdca8f7deb13fb73530228f370d7614

## Cycle: U4 (green)

- behavior: U4
- kind: green
- criterion: FR-004
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u4_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u4_test.dart --plain-name "Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output."`
- exit: 0
- at: 2026-09-04T01:41:48.294451Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u4_test.dart
00:00 +0: U4 (FR-004) U4 — Regeneration from an unchanged row MUST be byte-for-byte deterministic; a changed row regenerates deterministically with the change surfaced in the command output.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd func U4 --feature 072-dependency-mocks
    exit: 0
    purpose: scaffold the plain-function function for behavior U4 from its description
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build generated code for behavior U4
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: c71bc0b3d92811c1b68a5731089c5f125bdca8f7deb13fb73530228f370d7614
- hash: 45bbe659b28f438f9425765993b503c60dc9aa107598faeb58bb25da3235e116

## Cycle: U5 (red)

- behavior: U5
- kind: red
- classification: assertionFailure
- evidence: U5 (FR-005) U5 — A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock.
- criterion: FR-005
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u5_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u5_test.dart --plain-name "A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock."`
- exit: 1
- at: 2026-09-04T01:42:36.742248Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u5_test.dart
00:00 +0: U5 (FR-005) U5 — A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock.
00:00 +0 -1: U5 (FR-005) U5 — A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u5 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/u5_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u5_test.dart: U5 (FR-005) U5 — A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: d3e47ef94cb0bfd90e2d9daba7d99a317ff5ed3f204775dd053ff8c5d212bcc9

## Cycle: U5 (green)

- behavior: U5
- kind: green
- criterion: FR-005
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u5_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u5_test.dart --plain-name "A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock."`
- exit: 0
- at: 2026-09-04T01:43:48.805290Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u5_test.dart
00:00 +0: U5 (FR-005) U5 — A behavior whose trace names a declared dependency row MUST be routed to the dependency-mock surface by that declaration (through the declared-routing seam), with provenance naming the row; prose without a declaration MUST never route a behavior to a dependency mock.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd func U5 --feature 072-dependency-mocks
    exit: 0
    purpose: scaffold the plain-function function for behavior U5 from its description
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build generated code for behavior U5
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: d3e47ef94cb0bfd90e2d9daba7d99a317ff5ed3f204775dd053ff8c5d212bcc9
- hash: 14dbb4e5f893f8109bc33567de9ff4108568ceb8702198f178e80f491177a79a

## Cycle: U6 (red)

- behavior: U6
- kind: red
- classification: assertionFailure
- evidence: U6 (FR-006) U6 — A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop's explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double.
- criterion: FR-006
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u6_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u6_test.dart --plain-name "A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop's explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double."`
- exit: 1
- at: 2026-09-04T01:44:36.937018Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u6_test.dart
00:00 +0: U6 (FR-006) U6 — A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop's explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double.
00:00 +0 -1: U6 (FR-006) U6 — A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop's explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u6 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/u6_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u6_test.dart: U6 (FR-006) U6 — A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop's explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 209f039a0e55b6006f967c69ed38220d2aeeadb40c48ab2a53e9099d0a2be64d

## Cycle: U6 (green)

- behavior: U6
- kind: green
- criterion: FR-006
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u6_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u6_test.dart --plain-name "A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop's explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double."`
- exit: 0
- at: 2026-09-04T01:45:49.096819Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u6_test.dart
00:00 +0: U6 (FR-006) U6 — A behavior routed to a dependency mock whose mock artifacts are absent MUST be refused (or auto-generated under the loop's explicit generation gate) with `zfa mock dependency <Name>` named as the fix — never a silently absent test double.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd func U6 --feature 072-dependency-mocks
    exit: 0
    purpose: scaffold the plain-function function for behavior U6 from its description
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build generated code for behavior U6
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 209f039a0e55b6006f967c69ed38220d2aeeadb40c48ab2a53e9099d0a2be64d
- hash: d9c7b551f726ea81202c85fc7f34eb2a8ef2e4ab14a31a46c623a685d954ff61

## Cycle: U7 (red)

- behavior: U7
- kind: red
- classification: assertionFailure
- evidence: U7 (FR-007) U7 — Mock priority (P1/P2/P3) MUST order dependency-mock materialization in the loop (P1 → P2 → P3 → unprioritized, declaration-order-stable within a tier), with the order visible in the plan artifact.
- criterion: FR-007
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u7_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u7_test.dart --plain-name "Mock priority (P1/P2/P3) MUST order dependency-mock materialization in the loop (P1 → P2 → P3 → unprioritized, declaration-order-stable within a tier), with the order visible in the plan artifact."`
- exit: 1
- at: 2026-09-04T01:46:36.382655Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u7_test.dart
00:00 +0: U7 (FR-007) U7 — Mock priority (P1/P2/P3) MUST order dependency-mock materialization in the loop (P1 → P2 → P3 → unprioritized, declaration-order-stable within a tier), with the order visible in the plan artifact.
00:00 +0 -1: U7 (FR-007) U7 — Mock priority (P1/P2/P3) MUST order dependency-mock materialization in the loop (P1 → P2 → P3 → unprioritized, declaration-order-stable within a tier), with the order visible in the plan artifact. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u7 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/u7_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u7_test.dart: U7 (FR-007) U7 — Mock priority (P1/P2/P3) MUST order dependency-mock materialization in the loop (P1 → P2 → P3 → unprioritized, declaration-order-stable within a tier), with the order visible in the plan artifact.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 948a76346e3d0e2cffca18fe521accff7c93a96d8ebb3be700b13bba83fb8603

## Cycle: U7 (green)

- behavior: U7
- kind: green
- criterion: FR-007
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u7_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u7_test.dart --plain-name "Mock priority (P1/P2/P3) MUST order dependency-mock materialization in the loop (P1 → P2 → P3 → unprioritized, declaration-order-stable within a tier), with the order visible in the plan artifact."`
- exit: 0
- at: 2026-09-04T01:47:47.870218Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u7_test.dart
00:00 +0: U7 (FR-007) U7 — Mock priority (P1/P2/P3) MUST order dependency-mock materialization in the loop (P1 → P2 → P3 → unprioritized, declaration-order-stable within a tier), with the order visible in the plan artifact.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd func U7 --feature 072-dependency-mocks
    exit: 0
    purpose: scaffold the plain-function function for behavior U7 from its description
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build generated code for behavior U7
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 948a76346e3d0e2cffca18fe521accff7c93a96d8ebb3be700b13bba83fb8603
- hash: 1411bcd90712c28822f5a073f34280f6de0e82e8ad9d18e9a3f9c66fc966f887

## Cycle: U8 (red)

- behavior: U8
- kind: red
- classification: assertionFailure
- evidence: U8 (FR-008) U8 — A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock.
- criterion: FR-008
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u8_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u8_test.dart --plain-name "A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock."`
- exit: 1
- at: 2026-09-04T01:48:34.842370Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u8_test.dart
00:00 +0: U8 (FR-008) U8 — A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock.
00:00 +0 -1: U8 (FR-008) U8 — A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u8 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/u8_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u8_test.dart: U8 (FR-008) U8 — A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 01383c4f0027d47f3586f6082615e2863e4e7c09a4c56c4f27bce0325424e3dd

## Cycle: U8 (green)

- behavior: U8
- kind: green
- criterion: FR-008
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u8_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u8_test.dart --plain-name "A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock."`
- exit: 0
- at: 2026-09-04T01:49:44.630036Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u8_test.dart
00:00 +0: U8 (FR-008) U8 — A declared row that is malformed (unparseable signatures, duplicate dependency name, unsupported kind) MUST cause a refusal naming the row and the defect — never a guessed or wrong-shaped mock.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd func U8 --feature 072-dependency-mocks
    exit: 0
    purpose: scaffold the plain-function function for behavior U8 from its description
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build generated code for behavior U8
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 01383c4f0027d47f3586f6082615e2863e4e7c09a4c56c4f27bce0325424e3dd
- hash: 3051a109aa750b8d243eaffef01d393cd81c8513f9ba418b2297929f6900907b

## Cycle: U9 (red)

- behavior: U9
- kind: red
- classification: assertionFailure
- evidence: U9 (FR-009) U9 — `zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row.
- criterion: FR-009
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u9_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u9_test.dart --plain-name "`zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row."`
- exit: 1
- at: 2026-09-04T01:50:30.102887Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u9_test.dart
00:00 +0: U9 (FR-009) U9 — `zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row.
00:00 +0 -1: U9 (FR-009) U9 — `zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u9 not implemented>
  
  package:matcher                                  expect
  test/tdd/072-dependency-mocks/u9_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u9_test.dart: U9 (FR-009) U9 — `zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 57b4b4f82b704e471ee10e0227791a78dd445f3778dfabbb88964055e81a0616

## Cycle: U9 (green)

- behavior: U9
- kind: green
- criterion: FR-009
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u9_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u9_test.dart --plain-name "`zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row."`
- exit: 0
- at: 2026-09-04T01:51:40.785242Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u9_test.dart
00:00 +0: U9 (FR-009) U9 — `zfa tdd realize --adapter <Name>` MUST accept a generated dependency mock behind the declared interface, run the existing differential gates with the declared contract as the parity source, and refuse on surface drift naming the drifted member and the row.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd func U9 --feature 072-dependency-mocks
    exit: 0
    purpose: scaffold the plain-function function for behavior U9 from its description
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build generated code for behavior U9
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 57b4b4f82b704e471ee10e0227791a78dd445f3778dfabbb88964055e81a0616
- hash: e42a3f6d492cb2531cc561d8c9064aed28d6cc9a9dbb42521fca98c694e42cc8

## Cycle: U10 (red)

- behavior: U10
- kind: red
- classification: assertionFailure
- evidence: U10 (FR-010) U10 — Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature.
- criterion: FR-010
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u10_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u10_test.dart --plain-name "Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature."`
- exit: 1
- at: 2026-09-04T01:52:27.364685Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u10_test.dart
00:00 +0: U10 (FR-010) U10 — Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature.
00:00 +0 -1: U10 (FR-010) U10 — Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u10 not implemented>
  
  package:matcher                                   expect
  test/tdd/072-dependency-mocks/u10_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u10_test.dart: U10 (FR-010) U10 — Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 110a9d3a4b88f2c21fd218896a7e5db28fd3d715530bbd7936fc0b3eafa65560

## Cycle: U10 (green)

- behavior: U10
- kind: green
- criterion: FR-010
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u10_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u10_test.dart --plain-name "Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature."`
- exit: 0
- at: 2026-09-04T01:53:40.072408Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/u10_test.dart
00:00 +0: U10 (FR-010) U10 — Every generated dependency-mock artifact MUST be recorded in the artifact registry, traceable to its dependency row and feature.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd func U10 --feature 072-dependency-mocks
    exit: 0
    purpose: scaffold the plain-function function for behavior U10 from its description
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build generated code for behavior U10
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 110a9d3a4b88f2c21fd218896a7e5db28fd3d715530bbd7936fc0b3eafa65560
- hash: ad0bf78586017e0388ce15b8d881643b21c22fd499bdad9475b6b742584d202c

## Cycle: A1 (green)

- behavior: A1
- kind: green
- criterion: AC-1
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a1_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a1_test.dart --plain-name "the generated interface exposes `signIn(email, password) -> User` and `signOut() -> void` with no additional, missing, or renamed members."`
- exit: 0
- at: 2026-09-04T01:54:51.634511Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a1_test.dart
00:00 +0: A1 (AC-1) A1 — the generated interface exposes `signIn(email, password) -> User` and `signOut() -> void` with no additional, missing, or renamed members.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A1 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A1 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A1
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 07fdb82eb0b428deddb4b164d9c488b2e8bdc3cd34ca1cbd3e60cb42f903a209
- hash: 7be42a9c46ca69dd80e1048f8ab771cdfee145908ca89e4277f64029223096c7

## Cycle: A3 (green)

- behavior: A3
- kind: green
- criterion: AC-3
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a3_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a3_test.dart --plain-name "the generated artifacts are byte-for-byte identical."`
- exit: 0
- at: 2026-09-04T01:56:01.158479Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a3_test.dart
00:00 +0: A3 (AC-3) A3 — the generated artifacts are byte-for-byte identical.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A3 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A3 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A3
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: b4bcce074d03a89c34c2886f9f7378b7b2744675c86446dfabd7caf8c6cadaa2
- hash: d6baf252d4f0b7c0f7183f62201bfff696aac0c5c9f8245daf08ae75783f0309

## Cycle: A4 (green)

- behavior: A4
- kind: green
- criterion: AC-4
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a4_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a4_test.dart --plain-name "it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add."`
- exit: 0
- at: 2026-09-04T01:57:11.929278Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a4_test.dart
00:00 +0: A4 (AC-4) A4 — it refuses non-zero with an author-actionable error naming the External Dependencies & Contracts table row to add.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A4 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A4 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A4
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 06b028056ba3e3440c4409cc4cf9219f1b06cb48380e87fc5ea72c4393f2644b
- hash: 7791dd990642d395dbd7979653e6bfa20595225a690eb668939f6d1f700dbe04

## Cycle: A5 (green)

- behavior: A5
- kind: green
- criterion: AC-5
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a5_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a5_test.dart --plain-name "the generated mock conforms to the storage contract the row declares (the rail is dependency-kind-agnostic across the declared service and storage kinds)."`
- exit: 0
- at: 2026-09-04T01:58:22.773478Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a5_test.dart
00:00 +0: A5 (AC-5) A5 — the generated mock conforms to the storage contract the row declares (the rail is dependency-kind-agnostic across the declared service and storage kinds).
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A5 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A5 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A5
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 736ac41a6f56f4c0542935c91652cd60d5c27a13672ec1ba15e3dfaaff4797da
- hash: a5244c0bdf0a3d9116d42deb34982e91e62b74c164253dee9240b5e046569787

## Cycle: A6 (green)

- behavior: A6
- kind: green
- criterion: AC-6
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a6_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a6_test.dart --plain-name "the harness wires the generated `FirebaseAuth` mock and the behavior tests through it."`
- exit: 0
- at: 2026-09-04T01:59:35.173582Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a6_test.dart
00:00 +0: A6 (AC-6) A6 — the harness wires the generated `FirebaseAuth` mock and the behavior tests through it.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A6 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A6 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A6
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 54d21b4c113981fcb832259af839b35c1cfd6744bd7408861cf71a1726e2cf84
- hash: c6a361b7491b92c5adff681d7b3dd790a9c794d38a6072c82217d7f20121f926

## Cycle: A7 (green)

- behavior: A7
- kind: green
- criterion: AC-7
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a7_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a7_test.dart --plain-name "it names the dependency row (dependency name + contract) as the consulted declaration."`
- exit: 0
- at: 2026-09-04T02:00:49.477322Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a7_test.dart
00:00 +0: A7 (AC-7) A7 — it names the dependency row (dependency name + contract) as the consulted declaration.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A7 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A7 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A7
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 96775db07d55c87c00b994890a89749b711cfcb77ee67c7283c9a50e87547811
- hash: 0d357f251ecac7300dcb418085b514a82b6ab23d5a002c92b5084c476c92987b

## Cycle: A8 (green)

- behavior: A8
- kind: green
- criterion: AC-8
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a8_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a8_test.dart --plain-name "the behavior is NOT routed to a dependency mock (no prose sniffing)."`
- exit: 0
- at: 2026-09-04T02:02:02.878062Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a8_test.dart
00:00 +0: A8 (AC-8) A8 — the behavior is NOT routed to a dependency mock (no prose sniffing).
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A8 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A8 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A8
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 6e7db183c011b6e87c93313ed4b58ae7e3ea779fea3424cd45333c50cfbd128b
- hash: 0359f04c01f37d6c59df7de28215d47bd01e7283f109ef3fb61a18e659f7984b

## Cycle: A9 (green)

- behavior: A9
- kind: green
- criterion: AC-9
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a9_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a9_test.dart --plain-name "the run refuses (or auto-generates under the loop's existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double."`
- exit: 0
- at: 2026-09-04T02:03:16.876027Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a9_test.dart
00:00 +0: A9 (AC-9) A9 — the run refuses (or auto-generates under the loop's existing generation gate) naming `zfa mock dependency <Name>` as the fix — never a silently absent test double.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A9 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A9 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A9
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 22958d044d819fbe52da52563d254572b047f74a76c8c1d965849a334e8c828b
- hash: 46673ab147190cee5e2de477ab43936ab5f0462873bd8017263b00b0928e4323

## Cycle: A10 (green)

- behavior: A10
- kind: green
- criterion: AC-10
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a10_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a10_test.dart --plain-name "the materialization order is exactly P1, P2, P3, none."`
- exit: 0
- at: 2026-09-04T02:04:33.755252Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a10_test.dart
00:00 +0: A10 (AC-10) A10 — the materialization order is exactly P1, P2, P3, none.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A10 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A10 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A10
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: de1d136660b22fb037155d4e04c8c64bb7834fda323d72191c376f5729660562
- hash: b4ea1083a6a3120eec1cb4e729b3e0648eec5a99103a348d9094684d1f7db276

## Cycle: A11 (green)

- behavior: A11
- kind: green
- criterion: AC-11
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a11_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a11_test.dart --plain-name "their relative order equals their declaration order in the spec, stably across runs."`
- exit: 0
- at: 2026-09-04T02:05:51.833307Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a11_test.dart
00:00 +0: A11 (AC-11) A11 — their relative order equals their declaration order in the spec, stably across runs.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A11 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A11 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A11
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 8f6fa53794466321cbbcd6eee051cbec98ac091f473ce7563aa6ebfc82ef0eb4
- hash: 55e5cfd3242fb78088b4a7064403cce2e09ea7239d7fd8d1d6835427330ce772

## Cycle: A12 (green)

- behavior: A12
- kind: green
- criterion: AC-12
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a12_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a12_test.dart --plain-name "each row's priority and resulting order position are visible."`
- exit: 0
- at: 2026-09-04T02:07:11.224229Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a12_test.dart
00:00 +0: A12 (AC-12) A12 — each row's priority and resulting order position are visible.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A12 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A12 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A12
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: b93e4ee3bb62734ee05e2f025f9e130c86f5de35c0f7ad14c948d29288d75dc1
- hash: 4cd7795ca6dad36d5c72680bd3da0720e9e2d2121ba11a887587ecd3d023820c

## Cycle: A13 (green)

- behavior: A13
- kind: green
- criterion: AC-13
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a13_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a13_test.dart --plain-name "the differential gates compare against the declared contract and the suite stays green through the swap."`
- exit: 0
- at: 2026-09-04T02:08:29.437976Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a13_test.dart
00:00 +0: A13 (AC-13) A13 — the differential gates compare against the declared contract and the suite stays green through the swap.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A13 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A13 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A13
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 03155df8ecfdc1915151e7c629dedeb3eaf62a78352502417da770b462995459
- hash: 6db3285c811390b18787a3f93a0723f47df4344eb1f9ab8a934ad6fd02509c83

## Cycle: A14 (green)

- behavior: A14
- kind: green
- criterion: AC-14
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a14_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a14_test.dart --plain-name "it refuses naming the missing method and the contract row — never silently swapping a drifting adapter."`
- exit: 0
- at: 2026-09-04T02:09:43.291724Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a14_test.dart
00:00 +0: A14 (AC-14) A14 — it refuses naming the missing method and the contract row — never silently swapping a drifting adapter.
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A14 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A14 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A14
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: bba768aaa9660f388592ef2734d3e30acf121d7ae91a0eabe843de3ee3461698
- hash: 6a1be1b8e74aadfc8d01b1c9858ed1dc69edc64540b55d4d3e420ebb8c1c8db2

## Cycle: A15 (green)

- behavior: A15
- kind: green
- criterion: AC-15
- test: /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a15_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a15_test.dart --plain-name "they run unchanged against the real adapter (same interface, same harness seam)."`
- exit: 0
- at: 2026-09-04T02:12:04.464787Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/072-dependency-mocks/test/tdd/072-dependency-mocks/a15_test.dart
00:00 +0: A15 (AC-15) A15 — they run unchanged against the real adapter (same interface, same harness seam).
00:00 +1: All tests passed!
```
- generation:
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart tdd compose A15 --feature 072-dependency-mocks
    exit: 0
    purpose: compose subject of behavior A15 against 10 green unit subject(s)
  - step: /opt/dart-sdk/bin/dart /workspace/zuraffa/.worktrees/072-dependency-mocks/bin/zfa.dart build
    exit: 1
    purpose: build composed code for behavior A15
- suite: baseline=1 guard=0 new=(none)

- schema: 1
- prev-hash: 47a725444edf23e1078344436b26f323934b5e9c935a62fddc39d55fc2c6fb16
- hash: a35072683855bdde18686c5f734e79da1d97cb2251cb7bf656ddebc5d9a8eef0

