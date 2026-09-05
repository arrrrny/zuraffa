# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- evidence: A1 (AC-1) A1 — both are allowed, an undeclared `/settings` push violates, and the navigator root still conforms by construction.
- subject-hash: 8f370a7ce8d379dc77911f03a6e50369b23de3cf43018d65d9943243e1aedd5e
- criterion: AC-1
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a1_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a1_test.dart --plain-name "both are allowed, an undeclared `/settings` push violates, and the navigator root still conforms by construction."`
- exit: 1
- at: 2026-09-05T13:19:07.130823Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a1_test.dart
00:00 +0: A1 (AC-1) A1 — both are allowed, an undeclared `/settings` push violates, and the navigator root still conforms by construction.
00:00 +0 -1: A1 (AC-1) A1 — both are allowed, an undeclared `/settings` push violates, and the navigator root still conforms by construction. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/a1_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a1_test.dart: A1 (AC-1) A1 — both are allowed, an undeclared `/settings` push violates, and the navigator root still conforms by construction.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 7fddee07de5135c6837fb4e19aac2a923fff0df4a8628430525a8c15e3c176c7

## Cycle: A2 (red)

- behavior: A2
- kind: red
- classification: assertionFailure
- evidence: A2 (AC-2) A2 — no route except the root is allowed.
- subject-hash: 80e08a6683e75151cc8fc843810b359bd3d7839e4926af0a571f5169d85b00b1
- criterion: AC-2
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a2_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a2_test.dart --plain-name "no route except the root is allowed."`
- exit: 1
- at: 2026-09-05T13:19:12.535275Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a2_test.dart
00:00 +0: A2 (AC-2) A2 — no route except the root is allowed.
00:00 +0 -1: A2 (AC-2) A2 — no route except the root is allowed. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a2 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/a2_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a2_test.dart: A2 (AC-2) A2 — no route except the root is allowed.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: aed902e459b921e329b9263abe008b668eb2952ec13f4f49879b197bda42cba5

## Cycle: A3 (red)

- behavior: A3
- kind: red
- classification: assertionFailure
- evidence: A3 (AC-3) A3 — LoginPage maps to the toaster binding and RegisterPage to inline.
- subject-hash: a06aef42f8f44dff81b17c273a5a32bb4481aa43c4482b9a57295b3ffb203b0e
- criterion: AC-3
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a3_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a3_test.dart --plain-name "LoginPage maps to the toaster binding and RegisterPage to inline."`
- exit: 1
- at: 2026-09-05T13:19:18.038542Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a3_test.dart
00:00 +0: A3 (AC-3) A3 — LoginPage maps to the toaster binding and RegisterPage to inline.
00:00 +0 -1: A3 (AC-3) A3 — LoginPage maps to the toaster binding and RegisterPage to inline. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a3 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/a3_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a3_test.dart: A3 (AC-3) A3 — LoginPage maps to the toaster binding and RegisterPage to inline.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 48cdcae3926ba1304dc8a9acb2a89df5f8e4901d74bd5593df583e853eb9bf8c

## Cycle: A4 (red)

- behavior: A4
- kind: red
- classification: assertionFailure
- evidence: A4 (AC-4) A4 — both descriptors carry their declared ids and kinds.
- subject-hash: f68a9c65c741e17195a1af00575d033ba303216671984a1445e745d38d9f4f2e
- criterion: AC-4
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a4_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a4_test.dart --plain-name "both descriptors carry their declared ids and kinds."`
- exit: 1
- at: 2026-09-05T13:19:23.557192Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a4_test.dart
00:00 +0: A4 (AC-4) A4 — both descriptors carry their declared ids and kinds.
00:00 +0 -1: A4 (AC-4) A4 — both descriptors carry their declared ids and kinds. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a4 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/a4_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a4_test.dart: A4 (AC-4) A4 — both descriptors carry their declared ids and kinds.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: aaf2a1261226b784a7c4264c25575ae7757cac011fc11b6a009fe43dec4a1362

## Cycle: A5 (red)

- behavior: A5
- kind: red
- classification: assertionFailure
- evidence: A5 (AC-5) A5 — it exposes the route table, the state bindings, and the contract name it was built from.
- subject-hash: 8c93aafc7ac681750ebf1e86a851a88ebbf8142eb08946ac8eb953d3bbf05695
- criterion: AC-5
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a5_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a5_test.dart --plain-name "it exposes the route table, the state bindings, and the contract name it was built from."`
- exit: 1
- at: 2026-09-05T13:19:29.211984Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a5_test.dart
00:00 +0: A5 (AC-5) A5 — it exposes the route table, the state bindings, and the contract name it was built from.
00:00 +0 -1: A5 (AC-5) A5 — it exposes the route table, the state bindings, and the contract name it was built from. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a5 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/a5_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a5_test.dart: A5 (AC-5) A5 — it exposes the route table, the state bindings, and the contract name it was built from.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 63f2b89119bf34238ac53af9f172d405cacc7a70ec212fe9f019ca3484267e42

## Cycle: A6 (red)

- behavior: A6
- kind: red
- classification: assertionFailure
- evidence: A6 (AC-6) A6 — each keeps its own identity and route set (no cross-contamination).
- subject-hash: 8db382d312c7e72eec1661e3c9bdf130634e0e258817a12c237ebd0918f37623
- criterion: AC-6
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a6_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a6_test.dart --plain-name "each keeps its own identity and route set (no cross-contamination)."`
- exit: 1
- at: 2026-09-05T13:19:34.729183Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a6_test.dart
00:00 +0: A6 (AC-6) A6 — each keeps its own identity and route set (no cross-contamination).
00:00 +0 -1: A6 (AC-6) A6 — each keeps its own identity and route set (no cross-contamination). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a6 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/a6_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/a6_test.dart: A6 (AC-6) A6 — each keeps its own identity and route set (no cross-contamination).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 824fe288433b93129edff6c78c3991f5b841126141cf3e6d3ff340f19b53d098

## Cycle: U1 (red)

- behavior: U1
- kind: red
- classification: assertionFailure
- evidence: U1 (FR-001) U1 — The system MUST provide a pure-Dart runtime binding built from a parsed `SkinContract` in one call.
- subject-hash: 807db919d367391ce0102d8ff6e5a86c93e68687cf4e906c60d515e876a4d46e
- criterion: FR-001
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u1_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u1_test.dart --plain-name "The system MUST provide a pure-Dart runtime binding built from a parsed `SkinContract` in one call."`
- exit: 1
- at: 2026-09-05T13:19:40.466302Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u1_test.dart
00:00 +0: U1 (FR-001) U1 — The system MUST provide a pure-Dart runtime binding built from a parsed `SkinContract` in one call.
00:00 +0 -1: U1 (FR-001) U1 — The system MUST provide a pure-Dart runtime binding built from a parsed `SkinContract` in one call. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u1 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/u1_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u1_test.dart: U1 (FR-001) U1 — The system MUST provide a pure-Dart runtime binding built from a parsed `SkinContract` in one call.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: db504104711f88cb233417f27146944d0ec88da48bf34679c8c566ee41d50c6c

## Cycle: U2 (red)

- behavior: U2
- kind: red
- classification: assertionFailure
- evidence: U2 (FR-002) U2 — The binding MUST derive the runtime route table from `contract.routes`, preserving the navigator-root conforming-by-construction rule.
- subject-hash: 3d5c71074567d40c2400ced82e0e70b66b3ce143bcf7be17c229f29ce350b8cc
- criterion: FR-002
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u2_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u2_test.dart --plain-name "The binding MUST derive the runtime route table from `contract.routes`, preserving the navigator-root conforming-by-construction rule."`
- exit: 1
- at: 2026-09-05T13:19:46.172488Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u2_test.dart
00:00 +0: U2 (FR-002) U2 — The binding MUST derive the runtime route table from `contract.routes`, preserving the navigator-root conforming-by-construction rule.
00:00 +0 -1: U2 (FR-002) U2 — The binding MUST derive the runtime route table from `contract.routes`, preserving the navigator-root conforming-by-construction rule. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u2 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/u2_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u2_test.dart: U2 (FR-002) U2 — The binding MUST derive the runtime route table from `contract.routes`, preserving the navigator-root conforming-by-construction rule.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 6cc3b97a2a684c41ae98f4dfe7112388302ac463b23e78588fb300eb5a1a416b

## Cycle: U3 (red)

- behavior: U3
- kind: red
- classification: assertionFailure
- evidence: U3 (FR-003) U3 — The binding MUST derive per-view state bindings from `contract.states` distinguishing toaster, inline, and none error handling, plus empty-state declarations.
- subject-hash: d67ad8b6878d70a34cb8cf081267274f594cf381f89777134e363c5c1f486d61
- criterion: FR-003
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u3_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u3_test.dart --plain-name "The binding MUST derive per-view state bindings from `contract.states` distinguishing toaster, inline, and none error handling, plus empty-state declarations."`
- exit: 1
- at: 2026-09-05T13:19:51.854790Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u3_test.dart
00:00 +0: U3 (FR-003) U3 — The binding MUST derive per-view state bindings from `contract.states` distinguishing toaster, inline, and none error handling, plus empty-state declarations.
00:00 +0 -1: U3 (FR-003) U3 — The binding MUST derive per-view state bindings from `contract.states` distinguishing toaster, inline, and none error handling, plus empty-state declarations. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u3 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/u3_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u3_test.dart: U3 (FR-003) U3 — The binding MUST derive per-view state bindings from `contract.states` distinguishing toaster, inline, and none error handling, plus empty-state declarations.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: a2a1686c3572cc1ae6692ee06311bd23568d84f606270dbc6ac659240b8d6434

## Cycle: U4 (red)

- behavior: U4
- kind: red
- classification: assertionFailure
- evidence: U4 (FR-004) U4 — The binding MUST derive audit-row descriptors from `contract.stateRows` carrying the declared id and kind.
- subject-hash: 4f1d9b595c953fe0a7a9f17c883e2d8c59bbe40d7d61961be64e4dfc245a3ce0
- criterion: FR-004
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u4_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u4_test.dart --plain-name "The binding MUST derive audit-row descriptors from `contract.stateRows` carrying the declared id and kind."`
- exit: 1
- at: 2026-09-05T13:19:57.579662Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u4_test.dart
00:00 +0: U4 (FR-004) U4 — The binding MUST derive audit-row descriptors from `contract.stateRows` carrying the declared id and kind.
00:00 +0 -1: U4 (FR-004) U4 — The binding MUST derive audit-row descriptors from `contract.stateRows` carrying the declared id and kind. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u4 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/u4_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u4_test.dart: U4 (FR-004) U4 — The binding MUST derive audit-row descriptors from `contract.stateRows` carrying the declared id and kind.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 111e82a82377b6d254fa241bf89c2e6489390c7942ff349d225bb821a3d237e4

## Cycle: U5 (red)

- behavior: U5
- kind: red
- classification: assertionFailure
- evidence: U5 (FR-005) U5 — The binding MUST carry the contract's declared name/identity so downstream violations and receipts can name their source.
- subject-hash: f2880ecb1172a2dac87d0615898240809ec4142356f7da75756436b6038764ce
- criterion: FR-005
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u5_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u5_test.dart --plain-name "The binding MUST carry the contract's declared name/identity so downstream violations and receipts can name their source."`
- exit: 1
- at: 2026-09-05T13:20:03.425476Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u5_test.dart
00:00 +0: U5 (FR-005) U5 — The binding MUST carry the contract's declared name/identity so downstream violations and receipts can name their source.
00:00 +0 -1: U5 (FR-005) U5 — The binding MUST carry the contract's declared name/identity so downstream violations and receipts can name their source. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u5 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/u5_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u5_test.dart: U5 (FR-005) U5 — The binding MUST carry the contract's declared name/identity so downstream violations and receipts can name their source.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 5f3ea78e9c1c544e1fa80b732df181cc5868eb4996b61bd49ad0ee7ed2571865

## Cycle: U6 (red)

- behavior: U6
- kind: red
- classification: assertionFailure
- evidence: U6 (FR-006) U6 — The binding MUST stay free of any UI-framework dependency (engine lane, pure Dart).
- subject-hash: d87584a8fae5a99a4ab3280e8b98573c761b4b5effe6d60b72bb1eb50e37d0fb
- criterion: FR-006
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u6_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u6_test.dart --plain-name "The binding MUST stay free of any UI-framework dependency (engine lane, pure Dart)."`
- exit: 1
- at: 2026-09-05T13:20:09.154227Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u6_test.dart
00:00 +0: U6 (FR-006) U6 — The binding MUST stay free of any UI-framework dependency (engine lane, pure Dart).
00:00 +0 -1: U6 (FR-006) U6 — The binding MUST stay free of any UI-framework dependency (engine lane, pure Dart). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u6 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/u6_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u6_test.dart: U6 (FR-006) U6 — The binding MUST stay free of any UI-framework dependency (engine lane, pure Dart).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 14e40f5b8d069cdd2fe1995297b043f156c466e380ac09547e617a206166bacb

## Cycle: U7 (red)

- behavior: U7
- kind: red
- classification: assertionFailure
- evidence: U7 (FR-007) U7 — The binding MUST be exported from the skin barrel for the Flutter shell to consume across the package boundary.
- subject-hash: 7711282d5ee7f31af173d3adb8838b4b23db381d8fb0a00133e1a8b2daac27ec
- criterion: FR-007
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u7_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u7_test.dart --plain-name "The binding MUST be exported from the skin barrel for the Flutter shell to consume across the package boundary."`
- exit: 1
- at: 2026-09-05T13:20:14.944491Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u7_test.dart
00:00 +0: U7 (FR-007) U7 — The binding MUST be exported from the skin barrel for the Flutter shell to consume across the package boundary.
00:00 +0 -1: U7 (FR-007) U7 — The binding MUST be exported from the skin barrel for the Flutter shell to consume across the package boundary. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u7 not implemented>
  
  package:matcher                                       expect
  test/tdd/079-skin-contract-binding/u7_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/079-skin-contract-binding/u7_test.dart: U7 (FR-007) U7 — The binding MUST be exported from the skin barrel for the Flutter shell to consume across the package boundary.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 3f7c65cb1bbfd2858a611ffe4e46eb34c760e92c9d2ae6227445ded67c30f542


## Cycle evidence (2026-09-05)

- All 13 behaviors (A1-A6, U1-U7) driven through `zfa tdd gen` + `zfa tdd verify-red`:
  certified honestly red (`classification=assertion`).
- Implementation: `lib/src/skin/skin_contract_binding.dart` (binding + StateBinding) and
  `parseSkinContractDeclaration` (heading-name capture) in the parser module; exported
  through `lib/skin.dart` for the zuraffa_flutter shell.
- Green: 13 generated behavior tests + 14 real suite tests (2 new declaration tests) — all passing.
- make-level green evidence remains blocked by #1162 (subject-drift guard) — same documented gap as 078; green is proven by the passing suites.
