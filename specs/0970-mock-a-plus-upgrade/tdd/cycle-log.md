# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## 2026-09-04T18:33:00Z: 0970-mock-a-plus-upgrade A1 (red)

- behavior: A1
- kind: red
- exit: 64
- criterion: AC-1
- test: test/plugins/mock/mock_command_exit_test.dart
- command: `dart test test/plugins/mock/mock_command_exit_test.dart`
- at: 2026-09-04T18:33:00Z
- schema: 1
- prev-hash: genesis
- hash: 58cd268667a00f42d9fd5cb30295b04a17dbc76a35146027fde5b57666c214fd
- evidence: assertionFailure
- output:
```
00:00 +0: loading test/plugins/mock/mock_command_exit_test.dart
00:00 +0: A1: zfa mock json with no entity survives in-process and sets exit 64
(no test result, no summary — the process was killed mid-test)
REAL EXIT CODE: 64
```

## 2026-09-04T18:41:00Z: 0970-mock-a-plus-upgrade A1 (green)

- behavior: A1
- kind: green
- exit: 0
- criterion: AC-1
- test: test/plugins/mock/mock_command_exit_test.dart
- command: `dart test test/plugins/mock/mock_command_exit_test.dart`
- at: 2026-09-04T18:41:00Z
- schema: 1
- prev-hash: 58cd268667a00f42d9fd5cb30295b04a17dbc76a35146027fde5b57666c214fd
- hash: 6c4b06b93ea5e166f447ff3e4d8bde408b8b7a9bccaae030be4378da6c41966e
- evidence: testPassed
- output:
```
00:00 +2: All tests passed!
```

## 2026-09-04T18:50:00Z: 0970-mock-a-plus-upgrade A2 (red)

- behavior: A2
- kind: red
- exit: 1
- criterion: AC-2
- test: test/plugins/mock/mock_json_output_test.dart
- command: `dart test test/plugins/mock/mock_json_output_test.dart`
- at: 2026-09-04T18:50:00Z
- schema: 1
- prev-hash: genesis
- hash: 68085ee582f69984026b07d9ffd20dd87aa539fc5b152ae25b2adbc77984e5a1
- evidence: assertionFailure
- output:
```
00:00 +0 -4: Some tests failed.
  A2 [E]: FormatException: Unexpected character — stdout is "Missing argument for '--json'", not an envelope
  A3a/A3b [E]: FormatException — data/json have no --json flag
  A2b [E]: Expected: <1> Actual: <0> — the failure path exits 0
```

## 2026-09-04T19:02:00Z: 0970-mock-a-plus-upgrade A2 (green)

- behavior: A2
- kind: green
- exit: 0
- criterion: AC-2
- test: test/plugins/mock/mock_json_output_test.dart
- command: `dart test test/plugins/mock/mock_json_output_test.dart`
- at: 2026-09-04T19:02:00Z
- schema: 1
- prev-hash: 68085ee582f69984026b07d9ffd20dd87aa539fc5b152ae25b2adbc77984e5a1
- hash: 7a7e4e490d06b765601c9b04bc033fdc15d18eeb5d497f0436f601410bc451a4
- evidence: testPassed
- output:
```
00:00 +4: All tests passed!
```

## 2026-09-04T18:50:00Z: 0970-mock-a-plus-upgrade A3 (red)

- behavior: A3
- kind: red
- exit: 1
- criterion: AC-2
- test: test/plugins/mock/mock_json_output_test.dart
- command: `dart test test/plugins/mock/mock_json_output_test.dart`
- at: 2026-09-04T18:50:00Z
- schema: 1
- prev-hash: genesis
- hash: 204c602c393933acc14ebfe3ff088106dcaa990a7e6f4b5cd530f5142c5769c3
- evidence: assertionFailure
- output:
```
00:00 +0 -4: Some tests failed.
  A2 [E]: FormatException: Unexpected character — stdout is "Missing argument for '--json'", not an envelope
  A3a/A3b [E]: FormatException — data/json have no --json flag
  A2b [E]: Expected: <1> Actual: <0> — the failure path exits 0
```

## 2026-09-04T19:02:00Z: 0970-mock-a-plus-upgrade A3 (green)

- behavior: A3
- kind: green
- exit: 0
- criterion: AC-2
- test: test/plugins/mock/mock_json_output_test.dart
- command: `dart test test/plugins/mock/mock_json_output_test.dart`
- at: 2026-09-04T19:02:00Z
- schema: 1
- prev-hash: 204c602c393933acc14ebfe3ff088106dcaa990a7e6f4b5cd530f5142c5769c3
- hash: 8945f3adc4daeaf4c61cd2fee15a4e14ffad2f411b54319ccaa564d4a0a8b346
- evidence: testPassed
- output:
```
00:00 +4: All tests passed!
```

## 2026-09-04T18:58:00Z: 0970-mock-a-plus-upgrade A4 (red)

- behavior: A4
- kind: red
- exit: 1
- criterion: AC-3
- test: test/plugins/mock/mock_certification_receipt_test.dart
- command: `dart test test/plugins/mock/mock_certification_receipt_test.dart`
- at: 2026-09-04T18:58:00Z
- schema: 1
- prev-hash: genesis
- hash: e64f7b6524b57dc334a44d15df8dba3447cc1ea35a50cda2586c4f17ddc3cfc3
- evidence: assertionFailure
- output:
```
00:00 +0 -4: Some tests failed.
  A4 [E]: Expected: <True> Actual: <False> — .zfa/receipts/mock-product.json does not exist after create
  A4b/A5/A5b [E]: no receipts, proof check nothing to prove
```

## 2026-09-04T19:06:00Z: 0970-mock-a-plus-upgrade A4 (green)

- behavior: A4
- kind: green
- exit: 0
- criterion: AC-3
- test: test/plugins/mock/mock_certification_receipt_test.dart
- command: `dart test test/plugins/mock/mock_certification_receipt_test.dart`
- at: 2026-09-04T19:06:00Z
- schema: 1
- prev-hash: e64f7b6524b57dc334a44d15df8dba3447cc1ea35a50cda2586c4f17ddc3cfc3
- hash: 070979815e3d2b04a6ccc541b13c7ebf7fee1b3fa080d022c0b14488cac856ff
- evidence: testPassed
- output:
```
00:00 +4: All tests passed!
```

## 2026-09-04T18:58:00Z: 0970-mock-a-plus-upgrade A5 (red)

- behavior: A5
- kind: red
- exit: 1
- criterion: AC-3
- test: test/plugins/mock/mock_certification_receipt_test.dart
- command: `dart test test/plugins/mock/mock_certification_receipt_test.dart`
- at: 2026-09-04T18:58:00Z
- schema: 1
- prev-hash: genesis
- hash: e1ce0cb5f3ab14cf13e4cb9eee4da037ed284dcefad16041133b19eade0817bb
- evidence: assertionFailure
- output:
```
00:00 +0 -4: Some tests failed.
  A4 [E]: Expected: <True> Actual: <False> — .zfa/receipts/mock-product.json does not exist after create
  A4b/A5/A5b [E]: no receipts, proof check nothing to prove
```

## 2026-09-04T19:06:00Z: 0970-mock-a-plus-upgrade A5 (green)

- behavior: A5
- kind: green
- exit: 0
- criterion: AC-3
- test: test/plugins/mock/mock_certification_receipt_test.dart
- command: `dart test test/plugins/mock/mock_certification_receipt_test.dart`
- at: 2026-09-04T19:06:00Z
- schema: 1
- prev-hash: e1ce0cb5f3ab14cf13e4cb9eee4da037ed284dcefad16041133b19eade0817bb
- hash: 26217c77f388dbc4ace847d7cd8132f48b397cd9421ecc75f97d805b041d2629
- evidence: testPassed
- output:
```
00:00 +4: All tests passed!
```

## 2026-09-04T19:04:00Z: 0970-mock-a-plus-upgrade A6 (red)

- behavior: A6
- kind: red
- exit: 1
- criterion: AC-4
- test: test/plugins/mock/mock_certify_gate_test.dart
- command: `dart test test/plugins/mock/mock_certify_gate_test.dart`
- at: 2026-09-04T19:04:00Z
- schema: 1
- prev-hash: genesis
- hash: 10df6c8e9457a777a5ef3c9feef81357ab5d9293ca18dea0d8bb62b3f3ca27a8
- evidence: compileError
- output:
```
00:00 +0 -1: loading test/plugins/mock/mock_certify_gate_test.dart [E]
  Error: Undefined name 'MockCertifier' — the gate does not exist
```

## 2026-09-04T19:12:00Z: 0970-mock-a-plus-upgrade A6 (green)

- behavior: A6
- kind: green
- exit: 0
- criterion: AC-4
- test: test/plugins/mock/mock_certify_gate_test.dart
- command: `dart test test/plugins/mock/mock_certify_gate_test.dart`
- at: 2026-09-04T19:12:00Z
- schema: 1
- prev-hash: 10df6c8e9457a777a5ef3c9feef81357ab5d9293ca18dea0d8bb62b3f3ca27a8
- hash: 62f92ae682b07d6d54051ccbdb164352e63d3d796a0434119523ab27de3352a6
- evidence: testPassed
- output:
```
00:00 +4: All tests passed!
```

## 2026-09-04T19:14:00Z: 0970-mock-a-plus-upgrade A6 (green)

- behavior: A6
- kind: green
- exit: 0
- criterion: AC-4
- test: test/plugins/mock/mock_certify_gate_integration_test.dart
- command: `dart test --preset=integration test/plugins/mock/mock_certify_gate_integration_test.dart`
- at: 2026-09-04T19:14:00Z
- schema: 1
- prev-hash: 62f92ae682b07d6d54051ccbdb164352e63d3d796a0434119523ab27de3352a6
- hash: c0e3b7a5d4e75aa75f0b60598b7af64085e0f547e98d07b8c00627b373a85d62
- evidence: testPassed
- output:
```
00:13 +1: All tests passed! (dart test --preset=integration, the REAL dart analyze subprocess over the emitted mock files)
```

## 2026-09-04T19:04:00Z: 0970-mock-a-plus-upgrade A7 (red)

- behavior: A7
- kind: red
- exit: 1
- criterion: AC-4
- test: test/plugins/mock/mock_certify_gate_test.dart
- command: `dart test test/plugins/mock/mock_certify_gate_test.dart`
- at: 2026-09-04T19:04:00Z
- schema: 1
- prev-hash: genesis
- hash: cd7ad4013d6312cdca8fc88145af7d393ee3556b4d7b022c63ab93c80d8043e8
- evidence: compileError
- output:
```
00:00 +0 -1: loading test/plugins/mock/mock_certify_gate_test.dart [E]
  Error: Undefined name 'MockCertifier' — the gate does not exist
```

## 2026-09-04T19:12:00Z: 0970-mock-a-plus-upgrade A7 (green)

- behavior: A7
- kind: green
- exit: 0
- criterion: AC-4
- test: test/plugins/mock/mock_certify_gate_test.dart
- command: `dart test test/plugins/mock/mock_certify_gate_test.dart`
- at: 2026-09-04T19:12:00Z
- schema: 1
- prev-hash: cd7ad4013d6312cdca8fc88145af7d393ee3556b4d7b022c63ab93c80d8043e8
- hash: 981029c328ad4c1bd0e54a3f185d863e304d2b1b28eeeccd9add7d79fccaa10b
- evidence: testPassed
- output:
```
00:00 +4: All tests passed!
```

## 2026-09-04T19:18:00Z: 0970-mock-a-plus-upgrade A8 (green)

- behavior: A8
- kind: green
- exit: 0
- criterion: AC-5
- test: test/plugins/mock/mock_provider_builder_suite_test.dart
- command: `dart test test/plugins/mock/mock_provider_builder_suite_test.dart`
- at: 2026-09-04T19:18:00Z
- schema: 1
- prev-hash: genesis
- hash: b14d488f4d335c70c6c5e2695a720c6d534dc13a66ce0bfd7bd53a5381c6f37d
- evidence: testPassed
- output:
```
00:00 +10: All tests passed! (characterization: pinned against the real builder output; mock_provider_builder.dart was NOT modified)
```

## 2026-09-04T19:25:00Z: 0970-mock-a-plus-upgrade T006 (refactor)

- behavior: T006
- kind: refactor
- exit: 0
- criterion: AC-1
- test: test/plugins/mock/
- command: `dart analyze lib/src/... test/plugins/mock/ && dart format . && dart test test/plugins/mock/`
- at: 2026-09-04T19:25:00Z
- schema: 1
- prev-hash: genesis
- hash: 26363a5f0d8e6b821cc333c998bf4a8ed3193a59c07058b88925aa5f8bb86010
- evidence: refactorClean
- output:
```
dart analyze: No issues found; dart format .: 0 changed; dart test test/plugins/mock/: 80 passed; chunked fast suite: green
```

