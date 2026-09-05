# Cycle Log: 078-skin-contract-schema

## Baseline (zfa tdd plan)

- **Date**: 2026-09-05
- **Derived by**: `zfa tdd plan 078-skin-contract-schema --migrate-spec` (exit 0)
- **Behaviors**: 7 acceptance (A1–A7), 7 unit (U1–U7) — 14 total, all PENDING
## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- evidence: A1 (AC-1) A1 — a typed model is returned with every field populated and the schema version reported.
- subject-hash: 1d487ddf22c79f697bea7c270e6fcb57f990bdbec2719ecd122120047fe842dd
- criterion: AC-1
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a1_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a1_test.dart --plain-name "a typed model is returned with every field populated and the schema version reported."`
- exit: 1
- at: 2026-09-05T12:43:23.573817Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a1_test.dart
00:00 +0: A1 (AC-1) A1 — a typed model is returned with every field populated and the schema version reported.
00:00 +0 -1: A1 (AC-1) A1 — a typed model is returned with every field populated and the schema version reported. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/a1_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a1_test.dart: A1 (AC-1) A1 — a typed model is returned with every field populated and the schema version reported.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: f3858d4062710d7247fbc114bd847d779f59ee085d27c99841a0bf4fae2c5bfe

## Cycle: A2 (red)

- behavior: A2
- kind: red
- classification: assertionFailure
- evidence: A2 (AC-2) A2 — it fails with an error naming the offending section/key — never a silent default.
- subject-hash: 8691f0ed2540be01cc15586c7cb203e60172c6c83b2c0169df735c25de22bcd8
- criterion: AC-2
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a2_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a2_test.dart --plain-name "it fails with an error naming the offending section/key — never a silent default."`
- exit: 1
- at: 2026-09-05T12:43:27.972402Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a2_test.dart
00:00 +0: A2 (AC-2) A2 — it fails with an error naming the offending section/key — never a silent default.
00:00 +0 -1: A2 (AC-2) A2 — it fails with an error naming the offending section/key — never a silent default. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a2 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/a2_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a2_test.dart: A2 (AC-2) A2 — it fails with an error naming the offending section/key — never a silent default.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: b36015501315fcaf2fd374704bbc22d31a32904aa5941a7fb46d0a4d6e18f5cd

## Cycle: A3 (red)

- behavior: A3
- kind: red
- classification: assertionFailure
- evidence: A3 (AC-3) A3 — `04-skin-contract.schema.json` is written next to the lane plan (issue #1111 SC-1).
- subject-hash: bc46c5056c4d2065bb2ff6a456e5acce1c7505a9076cedddf67f334de9987012
- criterion: AC-3
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a3_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a3_test.dart --plain-name "`04-skin-contract.schema.json` is written next to the lane plan (issue #1111 SC-1)."`
- exit: 1
- at: 2026-09-05T12:43:32.199411Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a3_test.dart
00:00 +0: A3 (AC-3) A3 — `04-skin-contract.schema.json` is written next to the lane plan (issue #1111 SC-1).
00:00 +0 -1: A3 (AC-3) A3 — `04-skin-contract.schema.json` is written next to the lane plan (issue #1111 SC-1). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a3 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/a3_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a3_test.dart: A3 (AC-3) A3 — `04-skin-contract.schema.json` is written next to the lane plan (issue #1111 SC-1).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: c26123873c17720986e74f353e8e4352467830413338b67af86bd200c583138d

## Cycle: A4 (red)

- behavior: A4
- kind: red
- classification: assertionFailure
- evidence: A4 (AC-4) A4 — every model field has a schema property and every schema property traces to a model field (no drift, no orphans).
- subject-hash: 89fff3480c74ce64edbc11dd7f2cc11a7e8d33831c422a839a3efb58d52f165a
- criterion: AC-4
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a4_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a4_test.dart --plain-name "every model field has a schema property and every schema property traces to a model field (no drift, no orphans)."`
- exit: 1
- at: 2026-09-05T12:43:36.675478Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a4_test.dart
00:00 +0: A4 (AC-4) A4 — every model field has a schema property and every schema property traces to a model field (no drift, no orphans).
00:00 +0 -1: A4 (AC-4) A4 — every model field has a schema property and every schema property traces to a model field (no drift, no orphans). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a4 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/a4_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a4_test.dart: A4 (AC-4) A4 — every model field has a schema property and every schema property traces to a model field (no drift, no orphans).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: b2073093cd50773cd51ff9a6229825d88e345f6d669a768e2b80c28229664c87

## Cycle: A5 (red)

- behavior: A5
- kind: red
- classification: assertionFailure
- evidence: A5 (AC-5) A5 — no schema file is written and nothing else about the plan changes.
- subject-hash: 45f06b8ff34ea6f624109e38a205b2d6812adb86f15889820e6d372654f12dd1
- criterion: AC-5
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a5_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a5_test.dart --plain-name "no schema file is written and nothing else about the plan changes."`
- exit: 1
- at: 2026-09-05T12:43:40.834968Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a5_test.dart
00:00 +0: A5 (AC-5) A5 — no schema file is written and nothing else about the plan changes.
00:00 +0 -1: A5 (AC-5) A5 — no schema file is written and nothing else about the plan changes. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a5 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/a5_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a5_test.dart: A5 (AC-5) A5 — no schema file is written and nothing else about the plan changes.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 7ac59dd963929e9b670184e1861134d9b9b7cb14bbf5ddf991a17911d9d81eb7

## Cycle: A6 (red)

- behavior: A6
- kind: red
- classification: assertionFailure
- evidence: A6 (AC-6) A6 — every spec with a Skin Contract section is discovered, parsed, and schema-validated, and all pass.
- subject-hash: d36997810b716dec2793cb7a55653c7d03c8a49e86814fd04d5fb0b3527400b2
- criterion: AC-6
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a6_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a6_test.dart --plain-name "every spec with a Skin Contract section is discovered, parsed, and schema-validated, and all pass."`
- exit: 1
- at: 2026-09-05T12:43:45.012372Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a6_test.dart
00:00 +0: A6 (AC-6) A6 — every spec with a Skin Contract section is discovered, parsed, and schema-validated, and all pass.
00:00 +0 -1: A6 (AC-6) A6 — every spec with a Skin Contract section is discovered, parsed, and schema-validated, and all pass. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a6 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/a6_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a6_test.dart: A6 (AC-6) A6 — every spec with a Skin Contract section is discovered, parsed, and schema-validated, and all pass.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: a58e1e853fff584dec2dc25765ea55c40adb4cdebec559719f4dffa54bd1b934

## Cycle: A7 (red)

- behavior: A7
- kind: red
- classification: assertionFailure
- evidence: A7 (AC-7) A7 — it fails naming the spec file and the violating key.
- subject-hash: 1b22799d317acfd9d2525b68afed50d4a1e242c9efb1fce7b90352256a2d8e23
- criterion: AC-7
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a7_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a7_test.dart --plain-name "it fails naming the spec file and the violating key."`
- exit: 1
- at: 2026-09-05T12:43:49.384144Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a7_test.dart
00:00 +0: A7 (AC-7) A7 — it fails naming the spec file and the violating key.
00:00 +0 -1: A7 (AC-7) A7 — it fails naming the spec file and the violating key. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a7 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/a7_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/a7_test.dart: A7 (AC-7) A7 — it fails naming the spec file and the violating key.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 152f106dd1eb85bac4eeac73546e6cbaea51d870cdf396536364ffa8acd11c46

## Cycle: U1 (red)

- behavior: U1
- kind: red
- classification: assertionFailure
- evidence: U1 (FR-001) U1 — The system MUST provide a typed skin-contract model with schema version, routes, states, platform rows, and state rows.
- subject-hash: ca8307706f3ee16787f99bbeb30a7a5230277e3c3c19ae9438fe260a2c762e9e
- criterion: FR-001
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u1_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u1_test.dart --plain-name "The system MUST provide a typed skin-contract model with schema version, routes, states, platform rows, and state rows."`
- exit: 1
- at: 2026-09-05T12:43:53.777481Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u1_test.dart
00:00 +0: U1 (FR-001) U1 — The system MUST provide a typed skin-contract model with schema version, routes, states, platform rows, and state rows.
00:00 +0 -1: U1 (FR-001) U1 — The system MUST provide a typed skin-contract model with schema version, routes, states, platform rows, and state rows. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u1 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/u1_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u1_test.dart: U1 (FR-001) U1 — The system MUST provide a typed skin-contract model with schema version, routes, states, platform rows, and state rows.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 985760039b7faab550bf363c8e4306e624731cc59847b4e951791bb84b9ccc83

## Cycle: U2 (red)

- behavior: U2
- kind: red
- classification: assertionFailure
- evidence: U2 (FR-002) U2 — The system MUST parse contract JSON into the model, failing with an error that names the offending section or key when input is malformed, incomplete, or carries unknown fields.
- subject-hash: 6c96fd4e856680f191cda1de91941714d432a1656bb6da09baca8bbdeca56ba3
- criterion: FR-002
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u2_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u2_test.dart --plain-name "The system MUST parse contract JSON into the model, failing with an error that names the offending section or key when input is malformed, incomplete, or carries unknown fields."`
- exit: 1
- at: 2026-09-05T12:43:58.169400Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u2_test.dart
00:00 +0: U2 (FR-002) U2 — The system MUST parse contract JSON into the model, failing with an error that names the offending section or key when input is malformed, incomplete, or carries unknown fields.
00:00 +0 -1: U2 (FR-002) U2 — The system MUST parse contract JSON into the model, failing with an error that names the offending section or key when input is malformed, incomplete, or carries unknown fields. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u2 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/u2_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u2_test.dart: U2 (FR-002) U2 — The system MUST parse contract JSON into the model, failing with an error that names the offending section or key when input is malformed, incomplete, or carries unknown fields.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: a57bef9e8f48ecd3e348054d8be67c59b9deea2fece181864ca4e31c4b0cae19

## Cycle: U3 (red)

- behavior: U3
- kind: red
- classification: assertionFailure
- evidence: U3 (FR-003) U3 — The system MUST serialize the model back to contract JSON that parses to an equal model (round-trip guarantee).
- subject-hash: 6c3383cf95b972497af27c93565938462461c8331146188543d35e5821610423
- criterion: FR-003
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u3_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u3_test.dart --plain-name "The system MUST serialize the model back to contract JSON that parses to an equal model (round-trip guarantee)."`
- exit: 1
- at: 2026-09-05T12:44:02.526221Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u3_test.dart
00:00 +0: U3 (FR-003) U3 — The system MUST serialize the model back to contract JSON that parses to an equal model (round-trip guarantee).
00:00 +0 -1: U3 (FR-003) U3 — The system MUST serialize the model back to contract JSON that parses to an equal model (round-trip guarantee). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u3 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/u3_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u3_test.dart: U3 (FR-003) U3 — The system MUST serialize the model back to contract JSON that parses to an equal model (round-trip guarantee).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: d6e71924c6592730f2f262042aa3ae9ee687da2ad06f926a49576820d7ebe49a

## Cycle: U4 (red)

- behavior: U4
- kind: red
- classification: assertionFailure
- evidence: U4 (FR-004) U4 — `zfa tdd plan` MUST emit `04-skin-contract.schema.json` derived from the model when (and only when) the target spec carries a `## Skin Contract:` section.
- subject-hash: 57839946217cfe15a015419792ba1a723490657444a9802f6f7d1b61c2e8d301
- criterion: FR-004
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u4_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u4_test.dart --plain-name "`zfa tdd plan` MUST emit `04-skin-contract.schema.json` derived from the model when (and only when) the target spec carries a `## Skin Contract:` section."`
- exit: 1
- at: 2026-09-05T12:44:07.075752Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u4_test.dart
00:00 +0: U4 (FR-004) U4 — `zfa tdd plan` MUST emit `04-skin-contract.schema.json` derived from the model when (and only when) the target spec carries a `## Skin Contract:` section.
00:00 +0 -1: U4 (FR-004) U4 — `zfa tdd plan` MUST emit `04-skin-contract.schema.json` derived from the model when (and only when) the target spec carries a `## Skin Contract:` section. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u4 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/u4_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u4_test.dart: U4 (FR-004) U4 — `zfa tdd plan` MUST emit `04-skin-contract.schema.json` derived from the model when (and only when) the target spec carries a `## Skin Contract:` section.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 108f413a1b96971af698fbce5adb4aa1ddd99ff0a39927b37a084a66c5f0dbfe

## Cycle: U5 (red)

- behavior: U5
- kind: red
- classification: assertionFailure
- evidence: U5 (FR-005) U5 — The emitted schema MUST be generated from the typed model's fields so the two cannot drift.
- subject-hash: 5d5175f201ad2f78aa0f41466e0cfe8bb00922b98428c1b8c95b032fd1371fee
- criterion: FR-005
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u5_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u5_test.dart --plain-name "The emitted schema MUST be generated from the typed model's fields so the two cannot drift."`
- exit: 1
- at: 2026-09-05T12:44:11.431751Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u5_test.dart
00:00 +0: U5 (FR-005) U5 — The emitted schema MUST be generated from the typed model's fields so the two cannot drift.
00:00 +0 -1: U5 (FR-005) U5 — The emitted schema MUST be generated from the typed model's fields so the two cannot drift. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u5 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/u5_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u5_test.dart: U5 (FR-005) U5 — The emitted schema MUST be generated from the typed model's fields so the two cannot drift.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: f8e7581bfbb43808fe3f1d7e31bc04df03e008622dd520f1f946bda70b0c506e

## Cycle: U6 (red)

- behavior: U6
- kind: red
- classification: assertionFailure
- evidence: U6 (FR-006) U6 — A test suite MUST walk every spec with a Skin Contract section, parse its contract, and validate it against the schema, failing with the spec path and violating key named.
- subject-hash: 30fb991c020bfe5c8b365bf724d32b2942e48361ab5b6b1dcc8aa9c20f5fcf2d
- criterion: FR-006
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u6_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u6_test.dart --plain-name "A test suite MUST walk every spec with a Skin Contract section, parse its contract, and validate it against the schema, failing with the spec path and violating key named."`
- exit: 1
- at: 2026-09-05T12:44:15.655876Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u6_test.dart
00:00 +0: U6 (FR-006) U6 — A test suite MUST walk every spec with a Skin Contract section, parse its contract, and validate it against the schema, failing with the spec path and violating key named.
00:00 +0 -1: U6 (FR-006) U6 — A test suite MUST walk every spec with a Skin Contract section, parse its contract, and validate it against the schema, failing with the spec path and violating key named. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u6 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/u6_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u6_test.dart: U6 (FR-006) U6 — A test suite MUST walk every spec with a Skin Contract section, parse its contract, and validate it against the schema, failing with the spec path and violating key named.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: bf1d1923db636eeb879d9eb68657bfb6c8df1a20ec4982120ab24615b5d1bbb4

## Cycle: U7 (red)

- behavior: U7
- kind: red
- classification: assertionFailure
- evidence: U7 (FR-007) U7 — The emitted schema MUST itself be valid JSON Schema (machine-parseable by standard validators).
- subject-hash: 0fc5feb3b565148f91f6455e0acb86406d094b0dad05927ff03b647cadca7476
- criterion: FR-007
- test: /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u7_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u7_test.dart --plain-name "The emitted schema MUST itself be valid JSON Schema (machine-parseable by standard validators)."`
- exit: 1
- at: 2026-09-05T12:44:19.986394Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u7_test.dart
00:00 +0: U7 (FR-007) U7 — The emitted schema MUST itself be valid JSON Schema (machine-parseable by standard validators).
00:00 +0 -1: U7 (FR-007) U7 — The emitted schema MUST itself be valid JSON Schema (machine-parseable by standard validators). [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_u7 not implemented>
  
  package:matcher                                      expect
  test/tdd/078-skin-contract-schema/u7_test.dart 29:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa/test/tdd/078-skin-contract-schema/u7_test.dart: U7 (FR-007) U7 — The emitted schema MUST itself be valid JSON Schema (machine-parseable by standard validators).

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 6e31c1722532a0733c3512bbb8ac0c3b75e4e226e70587226049f75eda0a4fe3


## Cycle evidence (2026-09-05)

- All 14 behaviors (A1-A7, U1-U7) driven through `zfa tdd gen` + `zfa tdd verify-red`:
  every one certified honestly red (`classification=assertion`) with hashed evidence above.
- Implementation landed: `lib/src/skin/contract/` (model, strict parser, schema generator —
  all three walk the same field tables), the plan-command emitter hook, and the subjects.
- Generated tests now run green locally: 14 behavior tests + 17 real suite tests
  (parser 9, emitter 5, repo-wide schema 3) = 31 passing.
- Known closure gap (#1162): `zfa tdd make` cannot append green evidence for
  hand-implemented subjects (subject-drift guard vs. the generator's own "replace the
  stub body" instruction; prose scenarios are `unexpressible` to the entity pipeline).
  The red evidence above is the loop's last honest record; green is proven by the
  passing suite, not by a make skip.
- Emitter live note: the plan-command hook delegates to the fully tested
  `emitSkinContractSchema` service; a live `zfa tdd plan 1005-...` run was deliberately
  NOT executed to avoid mutating that feature's existing tdd artifacts on this branch.
