# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: 071-zap-U1 (red)

- behavior: 071-zap-U1
- kind: red
- classification: loadError
- criterion: FR-006
- test: test/zap/zap_schema_test.dart
- command: `dart test test/zap/zap_schema_test.dart`
- exit: 1
- at: 2026-09-03T15:04:17.667475Z
- output:
```
00:00 +0: loading test/zap/zap_schema_test.dart
00:00 +0 -1: loading test/zap/zap_schema_test.dart [E]
  Failed to load "test/zap/zap_schema_test.dart":
  test/zap/zap_schema_test.dart:11:8: Error: Error when reading 'lib/src/zap/zap_schema.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_schema.dart';
         ^
  test/zap/zap_schema_test.dart:23:24: Error: Undefined name 'ZapSchema'.
          final schema = ZapSchema.forType(type);
                         ^^^^^^^^^
  test/zap/zap_schema_test.dart:54:19: Error: Undefined name 'ZapSchema'.
        final all = ZapSchema.
…[1091 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 1c9900cb527701b00af3f01102f0349604f39fa77e5007b919f92ac93767c6a0

## Cycle: 071-zap-U2 (red)

- behavior: 071-zap-U2
- kind: red
- classification: loadError
- criterion: FR-006
- test: test/zap/zap_schema_test.dart
- command: `dart test test/zap/zap_schema_test.dart`
- exit: 1
- at: 2026-09-03T15:04:17.693858Z
- output:
```
00:00 +0: loading test/zap/zap_schema_test.dart
00:00 +0 -1: loading test/zap/zap_schema_test.dart [E]
  Failed to load "test/zap/zap_schema_test.dart":
  test/zap/zap_schema_test.dart:11:8: Error: Error when reading 'lib/src/zap/zap_schema.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_schema.dart';
         ^
  test/zap/zap_schema_test.dart:23:24: Error: Undefined name 'ZapSchema'.
          final schema = ZapSchema.forType(type);
                         ^^^^^^^^^
  test/zap/zap_schema_test.dart:54:19: Error: Undefined name 'ZapSchema'.
        final all = ZapSchema.
…[1091 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: f25251c5073fd37d46d5456cd6c2e6dfb6f104a67b7f373a73d5329eefe948e9

## Cycle: 071-zap-U3 (red)

- behavior: 071-zap-U3
- kind: red
- classification: loadError
- criterion: FR-006
- test: test/zap/zap_schema_test.dart
- command: `dart test test/zap/zap_schema_test.dart`
- exit: 1
- at: 2026-09-03T15:04:17.697157Z
- output:
```
00:00 +0: loading test/zap/zap_schema_test.dart
00:00 +0 -1: loading test/zap/zap_schema_test.dart [E]
  Failed to load "test/zap/zap_schema_test.dart":
  test/zap/zap_schema_test.dart:11:8: Error: Error when reading 'lib/src/zap/zap_schema.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_schema.dart';
         ^
  test/zap/zap_schema_test.dart:23:24: Error: Undefined name 'ZapSchema'.
          final schema = ZapSchema.forType(type);
                         ^^^^^^^^^
  test/zap/zap_schema_test.dart:54:19: Error: Undefined name 'ZapSchema'.
        final all = ZapSchema.
…[1091 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 989e960cfe438371bf3539d2f93e28dc512a9b6c0d3ae4d06f7ea4fa856a4736

## Cycle: 071-zap-U4 (red)

- behavior: 071-zap-U4
- kind: red
- classification: loadError
- criterion: FR-007
- test: test/zap/zap_validator_test.dart
- command: `dart test test/zap/zap_validator_test.dart`
- exit: 1
- at: 2026-09-03T15:04:18.479177Z
- output:
```
00:00 +0: loading test/zap/zap_validator_test.dart
00:00 +0 -1: loading test/zap/zap_validator_test.dart [E]
  Failed to load "test/zap/zap_validator_test.dart":
  test/zap/zap_validator_test.dart:12:8: Error: Error when reading 'lib/src/zap/zap_golden.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_golden.dart';
         ^
  test/zap/zap_validator_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_schema.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_schema.dart';
         ^
  test/zap/zap_validator_test.dart:14:8: Error: Error when readi
…[4327 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 142354c654142bacad0da2d190bb982048e1dafb5f16f66107ea9380ee03c3a1

## Cycle: 071-zap-U5 (red)

- behavior: 071-zap-U5
- kind: red
- classification: loadError
- criterion: FR-007
- test: test/zap/zap_validator_test.dart
- command: `dart test test/zap/zap_validator_test.dart`
- exit: 1
- at: 2026-09-03T15:04:18.482526Z
- output:
```
00:00 +0: loading test/zap/zap_validator_test.dart
00:00 +0 -1: loading test/zap/zap_validator_test.dart [E]
  Failed to load "test/zap/zap_validator_test.dart":
  test/zap/zap_validator_test.dart:12:8: Error: Error when reading 'lib/src/zap/zap_golden.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_golden.dart';
         ^
  test/zap/zap_validator_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_schema.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_schema.dart';
         ^
  test/zap/zap_validator_test.dart:14:8: Error: Error when readi
…[4327 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 5e4b2f9b060c9f0d1853fcc5b321c09920847aca234e0ab171ee348bc4903211

## Cycle: 071-zap-U6 (red)

- behavior: 071-zap-U6
- kind: red
- classification: loadError
- criterion: FR-007
- test: test/zap/zap_validator_test.dart
- command: `dart test test/zap/zap_validator_test.dart`
- exit: 1
- at: 2026-09-03T15:04:18.484270Z
- output:
```
00:00 +0: loading test/zap/zap_validator_test.dart
00:00 +0 -1: loading test/zap/zap_validator_test.dart [E]
  Failed to load "test/zap/zap_validator_test.dart":
  test/zap/zap_validator_test.dart:12:8: Error: Error when reading 'lib/src/zap/zap_golden.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_golden.dart';
         ^
  test/zap/zap_validator_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_schema.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_schema.dart';
         ^
  test/zap/zap_validator_test.dart:14:8: Error: Error when readi
…[4327 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 445defaba084af98104177910a6c236fe356ae427644edd7407c1a2fdd653939

## Cycle: 071-zap-U7 (red)

- behavior: 071-zap-U7
- kind: red
- classification: loadError
- criterion: FR-007
- test: test/zap/zap_validator_test.dart
- command: `dart test test/zap/zap_validator_test.dart`
- exit: 1
- at: 2026-09-03T15:04:18.485982Z
- output:
```
00:00 +0: loading test/zap/zap_validator_test.dart
00:00 +0 -1: loading test/zap/zap_validator_test.dart [E]
  Failed to load "test/zap/zap_validator_test.dart":
  test/zap/zap_validator_test.dart:12:8: Error: Error when reading 'lib/src/zap/zap_golden.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_golden.dart';
         ^
  test/zap/zap_validator_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_schema.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_schema.dart';
         ^
  test/zap/zap_validator_test.dart:14:8: Error: Error when readi
…[4327 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 664ac330af3d20535953b633221be550e4f845bfb4896a2a163a4e3d1d5c2e1d

## Cycle: 071-zap-U8 (red)

- behavior: 071-zap-U8
- kind: red
- classification: loadError
- criterion: FR-001..FR-005, FR-013
- test: test/zap/zap_message_test.dart
- command: `dart test test/zap/zap_message_test.dart`
- exit: 1
- at: 2026-09-03T15:04:19.329770Z
- output:
```
00:00 +0: loading test/zap/zap_message_test.dart
00:00 +0 -1: loading test/zap/zap_message_test.dart [E]
  Failed to load "test/zap/zap_message_test.dart":
  test/zap/zap_message_test.dart:12:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_message_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_golden.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_golden.dart';
         ^
  test/zap/zap_message_test.dart:14:8: Error: Error when reading 'lib/src/za
…[8741 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 6cba77e8f9da548eff9f37df73889e2af6bf5befd4ca806763d552528d10aa15

## Cycle: 071-zap-U9 (red)

- behavior: 071-zap-U9
- kind: red
- classification: loadError
- criterion: FR-001..FR-005, FR-013
- test: test/zap/zap_message_test.dart
- command: `dart test test/zap/zap_message_test.dart`
- exit: 1
- at: 2026-09-03T15:04:19.332852Z
- output:
```
00:00 +0: loading test/zap/zap_message_test.dart
00:00 +0 -1: loading test/zap/zap_message_test.dart [E]
  Failed to load "test/zap/zap_message_test.dart":
  test/zap/zap_message_test.dart:12:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_message_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_golden.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_golden.dart';
         ^
  test/zap/zap_message_test.dart:14:8: Error: Error when reading 'lib/src/za
…[8741 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 4836f2fddc7095059b5b172973e7b940676e3fb9a07092b2afa83fc4307305ba

## Cycle: 071-zap-U10 (red)

- behavior: 071-zap-U10
- kind: red
- classification: loadError
- criterion: FR-001..FR-005, FR-013
- test: test/zap/zap_message_test.dart
- command: `dart test test/zap/zap_message_test.dart`
- exit: 1
- at: 2026-09-03T15:04:19.334211Z
- output:
```
00:00 +0: loading test/zap/zap_message_test.dart
00:00 +0 -1: loading test/zap/zap_message_test.dart [E]
  Failed to load "test/zap/zap_message_test.dart":
  test/zap/zap_message_test.dart:12:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_message_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_golden.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_golden.dart';
         ^
  test/zap/zap_message_test.dart:14:8: Error: Error when reading 'lib/src/za
…[8741 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 23839dedcf166e88d8ab0f46aa381d33bc15f93b5d3275a35a53b96e36489005

## Cycle: 071-zap-U11 (red)

- behavior: 071-zap-U11
- kind: red
- classification: loadError
- criterion: FR-001..FR-005, FR-013
- test: test/zap/zap_message_test.dart
- command: `dart test test/zap/zap_message_test.dart`
- exit: 1
- at: 2026-09-03T15:04:19.335757Z
- output:
```
00:00 +0: loading test/zap/zap_message_test.dart
00:00 +0 -1: loading test/zap/zap_message_test.dart [E]
  Failed to load "test/zap/zap_message_test.dart":
  test/zap/zap_message_test.dart:12:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_message_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_golden.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_golden.dart';
         ^
  test/zap/zap_message_test.dart:14:8: Error: Error when reading 'lib/src/za
…[8741 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 1f783897ce2e9e21e483ad1a15f406be0d6517b878a248a7362d8aafe3d411b8

## Cycle: 071-zap-U12 (red)

- behavior: 071-zap-U12
- kind: red
- classification: loadError
- criterion: FR-006, SC-001
- test: test/zap/zap_golden_test.dart
- command: `dart test test/zap/zap_golden_test.dart`
- exit: 1
- at: 2026-09-03T15:04:20.077095Z
- output:
```
00:00 +0: loading test/zap/zap_golden_test.dart
00:00 +0 -1: loading test/zap/zap_golden_test.dart [E]
  Failed to load "test/zap/zap_golden_test.dart":
  test/zap/zap_golden_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_golden.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_golden.dart';
         ^
  test/zap/zap_golden_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_message.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_message.dart';
         ^
  test/zap/zap_golden_test.dart:16:8: Error: Error when reading 'lib/src/zap/
…[2002 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 492b3334a50166aebb06c5d5380ca6f31eaf2adbe342fdb0fffd5dc5c2cef7ea

## Cycle: 071-zap-A1 (red)

- behavior: 071-zap-A1
- kind: red
- classification: loadError
- criterion: FR-006, SC-001
- test: test/zap/zap_golden_test.dart
- command: `dart test test/zap/zap_golden_test.dart`
- exit: 1
- at: 2026-09-03T15:04:20.079144Z
- output:
```
00:00 +0: loading test/zap/zap_golden_test.dart
00:00 +0 -1: loading test/zap/zap_golden_test.dart [E]
  Failed to load "test/zap/zap_golden_test.dart":
  test/zap/zap_golden_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_golden.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_golden.dart';
         ^
  test/zap/zap_golden_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_message.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_message.dart';
         ^
  test/zap/zap_golden_test.dart:16:8: Error: Error when reading 'lib/src/zap/
…[2002 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: b85cff97bc170edf90564182688cc0f41960fd289cb1c9310ea208554ace5f69

## Cycle: 071-zap-U13 (red)

- behavior: 071-zap-U13
- kind: red
- classification: loadError
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 1
- at: 2026-09-03T15:04:20.927353Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0 -1: loading test/zap/zap_host_test.dart [E]
  Failed to load "test/zap/zap_host_test.dart":
  test/zap/zap_host_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_host_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_executor.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_executor.dart';
         ^
  test/zap/zap_host_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_golden.d
…[8439 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 263c713724543ab857a41d7c4ca20513247407bdf47d0b467cb9bdc1ec1284a4

## Cycle: 071-zap-U14 (red)

- behavior: 071-zap-U14
- kind: red
- classification: loadError
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 1
- at: 2026-09-03T15:04:20.929408Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0 -1: loading test/zap/zap_host_test.dart [E]
  Failed to load "test/zap/zap_host_test.dart":
  test/zap/zap_host_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_host_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_executor.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_executor.dart';
         ^
  test/zap/zap_host_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_golden.d
…[8439 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 5bcba855a85ec550ffb526d143d10340994e38e407102cc210ffd4ec52003fce

## Cycle: 071-zap-U15 (red)

- behavior: 071-zap-U15
- kind: red
- classification: loadError
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 1
- at: 2026-09-03T15:04:20.930990Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0 -1: loading test/zap/zap_host_test.dart [E]
  Failed to load "test/zap/zap_host_test.dart":
  test/zap/zap_host_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_host_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_executor.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_executor.dart';
         ^
  test/zap/zap_host_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_golden.d
…[8439 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 742fbbb5fe2f59546e7af3b6a6b616ab114a58b6921e832254db2032c9f9db05

## Cycle: 071-zap-U16 (red)

- behavior: 071-zap-U16
- kind: red
- classification: loadError
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 1
- at: 2026-09-03T15:04:20.932336Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0 -1: loading test/zap/zap_host_test.dart [E]
  Failed to load "test/zap/zap_host_test.dart":
  test/zap/zap_host_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_host_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_executor.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_executor.dart';
         ^
  test/zap/zap_host_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_golden.d
…[8439 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 20efb86f62181bf8e990cafa07c109b7cefb4cfbbc4b97df7326e9d6aeff98bb

## Cycle: 071-zap-U17 (red)

- behavior: 071-zap-U17
- kind: red
- classification: loadError
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 1
- at: 2026-09-03T15:04:20.933632Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0 -1: loading test/zap/zap_host_test.dart [E]
  Failed to load "test/zap/zap_host_test.dart":
  test/zap/zap_host_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_host_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_executor.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_executor.dart';
         ^
  test/zap/zap_host_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_golden.d
…[8439 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 4ecabd6ec318bd8d803537e762f6a05383f7106dc170771b8340e5c9b33d882a

## Cycle: 071-zap-U18 (red)

- behavior: 071-zap-U18
- kind: red
- classification: loadError
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 1
- at: 2026-09-03T15:04:20.934923Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0 -1: loading test/zap/zap_host_test.dart [E]
  Failed to load "test/zap/zap_host_test.dart":
  test/zap/zap_host_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_host_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_executor.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_executor.dart';
         ^
  test/zap/zap_host_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_golden.d
…[8439 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: fe1cb25ce988f22b5f8d3322f97a8fc5cb9796ea7c3d41dbc477b7736d016fa5

## Cycle: 071-zap-A7 (red)

- behavior: 071-zap-A7
- kind: red
- classification: loadError
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 1
- at: 2026-09-03T15:04:20.936306Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0 -1: loading test/zap/zap_host_test.dart [E]
  Failed to load "test/zap/zap_host_test.dart":
  test/zap/zap_host_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_host_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_executor.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_executor.dart';
         ^
  test/zap/zap_host_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_golden.d
…[8439 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 75b62230e44c8592da4078d5aeed1db68b3a6bbf164cbe74e2d442dae831fe1d

## Cycle: 071-zap-A8 (red)

- behavior: 071-zap-A8
- kind: red
- classification: loadError
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 1
- at: 2026-09-03T15:04:20.937651Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0 -1: loading test/zap/zap_host_test.dart [E]
  Failed to load "test/zap/zap_host_test.dart":
  test/zap/zap_host_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_chain.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_chain.dart';
         ^
  test/zap/zap_host_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_executor.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_executor.dart';
         ^
  test/zap/zap_host_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_golden.d
…[8439 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 10f6a1bd23c2560f80a0c785281c526258ab302ffe551f08174e703581837ebd

## Cycle: 071-zap-U19 (red)

- behavior: 071-zap-U19
- kind: red
- classification: loadError
- criterion: FR-014
- test: test/zap/zap_client_test.dart
- command: `dart test test/zap/zap_client_test.dart`
- exit: 1
- at: 2026-09-03T15:04:21.687013Z
- output:
```
00:00 +0: loading test/zap/zap_client_test.dart
00:00 +0 -1: loading test/zap/zap_client_test.dart [E]
  Failed to load "test/zap/zap_client_test.dart":
  test/zap/zap_client_test.dart:13:8: Error: Error when reading 'lib/src/zap/zap_executor.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_executor.dart';
         ^
  test/zap/zap_client_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_host.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_host.dart';
         ^
  test/zap/zap_client_test.dart:15:8: Error: Error when reading 'lib/src/zap/za
…[3529 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: b0282d0805932428dea82a61b2c23abc142b280060e8cea8c0bf5842eb6553c5

## Cycle: 071-zap-A2 (red)

- behavior: 071-zap-A2
- kind: red
- classification: loadError
- criterion: FR-006, FR-008, SC-002
- test: test/zap/zap_conformance_test.dart
- command: `dart test test/zap/zap_conformance_test.dart`
- exit: 1
- at: 2026-09-03T15:04:30.421822Z
- output:
```
00:00 +0: loading test/zap/zap_conformance_test.dart
00:00 +0: zfa zap conform A2: zfa zap conform passes with the machine summary line
00:00 +0 -1: zfa zap conform A2: zfa zap conform passes with the machine summary line [E]
  Expected: match '^zap: conform checks=\d+ passed=\d+ failed=0 — OK$'
    Actual: 'Run "zfa help <command>" for more information about a command.'
  the final stdout line must be the machine summary: Run "zfa help <command>" for more information about a command.
  
  package:matcher                          expect
  test/zap/zap_conformance_test.dart 36:7  main.<fn>.<fn>
…[9805 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 5ca4fad460821e022467ea3aa9afec292e90e41b545de7b1ca1d001419b4925d

## Cycle: 071-zap-A3 (red)

- behavior: 071-zap-A3
- kind: red
- classification: loadError
- criterion: FR-006, FR-008, SC-002
- test: test/zap/zap_conformance_test.dart
- command: `dart test test/zap/zap_conformance_test.dart`
- exit: 1
- at: 2026-09-03T15:04:30.424094Z
- output:
```
00:00 +0: loading test/zap/zap_conformance_test.dart
00:00 +0: zfa zap conform A2: zfa zap conform passes with the machine summary line
00:00 +0 -1: zfa zap conform A2: zfa zap conform passes with the machine summary line [E]
  Expected: match '^zap: conform checks=\d+ passed=\d+ failed=0 — OK$'
    Actual: 'Run "zfa help <command>" for more information about a command.'
  the final stdout line must be the machine summary: Run "zfa help <command>" for more information about a command.
  
  package:matcher                          expect
  test/zap/zap_conformance_test.dart 36:7  main.<fn>.<fn>
…[9805 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: dd7d2a1d57a81fdae6b654f5a59d461fe28553798f3264b998579b16d6a5cc7f

## Cycle: 071-zap-U21 (red)

- behavior: 071-zap-U21
- kind: red
- classification: loadError
- criterion: FR-006, FR-008, SC-002
- test: test/zap/zap_conformance_test.dart
- command: `dart test test/zap/zap_conformance_test.dart`
- exit: 1
- at: 2026-09-03T15:04:30.426299Z
- output:
```
00:00 +0: loading test/zap/zap_conformance_test.dart
00:00 +0: zfa zap conform A2: zfa zap conform passes with the machine summary line
00:00 +0 -1: zfa zap conform A2: zfa zap conform passes with the machine summary line [E]
  Expected: match '^zap: conform checks=\d+ passed=\d+ failed=0 — OK$'
    Actual: 'Run "zfa help <command>" for more information about a command.'
  the final stdout line must be the machine summary: Run "zfa help <command>" for more information about a command.
  
  package:matcher                          expect
  test/zap/zap_conformance_test.dart 36:7  main.<fn>.<fn>
…[9805 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 9cb57997056ee2ff7ae8008c6eb7bda010602f11d58552e81b926b64bc8ebb14

## Cycle: 071-zap-U20 (red)

- behavior: 071-zap-U20
- kind: red
- classification: loadError
- criterion: FR-008, FR-009
- test: test/zap/zap_command_smoke_test.dart
- command: `dart test test/zap/zap_command_smoke_test.dart`
- exit: 1
- at: 2026-09-03T15:04:32.656663Z
- output:
```
00:00 +0: loading test/zap/zap_command_smoke_test.dart
00:00 +0: U20: zfa zap --help lists the three subcommands
00:00 +0 -1: U20: zfa zap --help lists the three subcommands [E]
  Expected: contains 'conform'
    Actual: '❌ Could not find a command named "zap".\n'
              '\n'
              'Did you mean one of these?\n'
              '  api\n'
              '\n'
              'Usage: zfa <command> [arguments]\n'
              '\n'
              'Global options:\n'
              '-h, --help         Print this usage information.\n'
              '-v, --version      Print version\n'
      
…[12132 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 5ef2c5454753d750304dc9f64feb6af2ebd97f03c55d6c49ceaa3678bbd14c62

## Cycle: 071-zap-A4 (red)

- behavior: 071-zap-A4
- kind: red
- classification: loadError
- criterion: FR-015, FR-017, SC-003, SC-004
- test: test/zap/zap_interop_test.dart
- command: `dart test test/zap/zap_interop_test.dart`
- exit: 1
- at: 2026-09-03T15:04:34.373734Z
- output:
```
00:00 +0: loading test/zap/zap_interop_test.dart
00:00 +0 -1: loading test/zap/zap_interop_test.dart [E]
  Failed to load "test/zap/zap_interop_test.dart":
  test/zap/zap_interop_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_client.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_client.dart';
         ^
  test/zap/zap_interop_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_message.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_message.dart';
         ^
  test/zap/zap_interop_test.dart:29:7: Error: No named parameter with th
…[2824 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: b759f7548a1608cdb6a789abd2cacd8f667215ece744d1d84e98c662644a0301

## Cycle: 071-zap-A5 (red)

- behavior: 071-zap-A5
- kind: red
- classification: loadError
- criterion: FR-015, FR-017, SC-003, SC-004
- test: test/zap/zap_interop_test.dart
- command: `dart test test/zap/zap_interop_test.dart`
- exit: 1
- at: 2026-09-03T15:04:34.377870Z
- output:
```
00:00 +0: loading test/zap/zap_interop_test.dart
00:00 +0 -1: loading test/zap/zap_interop_test.dart [E]
  Failed to load "test/zap/zap_interop_test.dart":
  test/zap/zap_interop_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_client.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_client.dart';
         ^
  test/zap/zap_interop_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_message.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_message.dart';
         ^
  test/zap/zap_interop_test.dart:29:7: Error: No named parameter with th
…[2824 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: b1d9995f5050b07981d8003b30a05e2680440617bba40be8fdf736e772b84630

## Cycle: 071-zap-A6 (red)

- behavior: 071-zap-A6
- kind: red
- classification: loadError
- criterion: FR-015, FR-017, SC-003, SC-004
- test: test/zap/zap_interop_test.dart
- command: `dart test test/zap/zap_interop_test.dart`
- exit: 1
- at: 2026-09-03T15:04:34.379567Z
- output:
```
00:00 +0: loading test/zap/zap_interop_test.dart
00:00 +0 -1: loading test/zap/zap_interop_test.dart [E]
  Failed to load "test/zap/zap_interop_test.dart":
  test/zap/zap_interop_test.dart:14:8: Error: Error when reading 'lib/src/zap/zap_client.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_client.dart';
         ^
  test/zap/zap_interop_test.dart:15:8: Error: Error when reading 'lib/src/zap/zap_message.dart': No such file or directory
  import 'package:zuraffa/src/zap/zap_message.dart';
         ^
  test/zap/zap_interop_test.dart:29:7: Error: No named parameter with th
…[2824 chars total]
```

- schema: 1
- prev-hash: genesis
- hash: 015e2d0a8181e4fbed87a4619144ef495f481f0cf1fa6a4b975c88645170812c

## Cycle: 071-zap-U1 (green)

- behavior: 071-zap-U1
- kind: green
- criterion: FR-006
- test: test/zap/zap_schema_test.dart
- command: `dart test test/zap/zap_schema_test.dart`
- exit: 0
- at: 2026-09-03T15:45:56.295560Z
- output:
```
00:00 +0: loading test/zap/zap_schema_test.dart
00:00 +0: ZapSchema — draft-07 per message type (U1) U1: mission has a draft-07 schema with the envelope
00:00 +1: ZapSchema — draft-07 per message type (U1) U1: evidence has a draft-07 schema with the envelope
00:00 +2: ZapSchema — draft-07 per message type (U1) U1: checkpoint has a draft-07 schema with the envelope
00:00 +3: ZapSchema — draft-07 per message type (U1) U1: receipt has a draft-07 schema with the envelope
00:00 +4: ZapSchema — draft-07 per message type (U1) U1: error has a draft-07 schema with the envelope
00:00 +5: ZapSchema — cov
…[1137 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 1c9900cb527701b00af3f01102f0349604f39fa77e5007b919f92ac93767c6a0
- hash: 66bb9bb038702bbe46204b669d8d6bbff5031918019643a2887e7243b74a235c

## Cycle: 071-zap-U2 (green)

- behavior: 071-zap-U2
- kind: green
- criterion: FR-006
- test: test/zap/zap_schema_test.dart
- command: `dart test test/zap/zap_schema_test.dart`
- exit: 0
- at: 2026-09-03T15:45:56.326919Z
- output:
```
00:00 +0: loading test/zap/zap_schema_test.dart
00:00 +0: ZapSchema — draft-07 per message type (U1) U1: mission has a draft-07 schema with the envelope
00:00 +1: ZapSchema — draft-07 per message type (U1) U1: evidence has a draft-07 schema with the envelope
00:00 +2: ZapSchema — draft-07 per message type (U1) U1: checkpoint has a draft-07 schema with the envelope
00:00 +3: ZapSchema — draft-07 per message type (U1) U1: receipt has a draft-07 schema with the envelope
00:00 +4: ZapSchema — draft-07 per message type (U1) U1: error has a draft-07 schema with the envelope
00:00 +5: ZapSchema — cov
…[1137 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: f25251c5073fd37d46d5456cd6c2e6dfb6f104a67b7f373a73d5329eefe948e9
- hash: 8197b54460571720b290dc90c28c3a45645a24d1845291b2af0f187162bdbed0

## Cycle: 071-zap-U3 (green)

- behavior: 071-zap-U3
- kind: green
- criterion: FR-006
- test: test/zap/zap_schema_test.dart
- command: `dart test test/zap/zap_schema_test.dart`
- exit: 0
- at: 2026-09-03T15:45:56.333157Z
- output:
```
00:00 +0: loading test/zap/zap_schema_test.dart
00:00 +0: ZapSchema — draft-07 per message type (U1) U1: mission has a draft-07 schema with the envelope
00:00 +1: ZapSchema — draft-07 per message type (U1) U1: evidence has a draft-07 schema with the envelope
00:00 +2: ZapSchema — draft-07 per message type (U1) U1: checkpoint has a draft-07 schema with the envelope
00:00 +3: ZapSchema — draft-07 per message type (U1) U1: receipt has a draft-07 schema with the envelope
00:00 +4: ZapSchema — draft-07 per message type (U1) U1: error has a draft-07 schema with the envelope
00:00 +5: ZapSchema — cov
…[1137 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 989e960cfe438371bf3539d2f93e28dc512a9b6c0d3ae4d06f7ea4fa856a4736
- hash: e0a190a640523f4becd158c7e7827aed5360a165911a180d3b877ec0c1402493

## Cycle: 071-zap-U4 (green)

- behavior: 071-zap-U4
- kind: green
- criterion: FR-007
- test: test/zap/zap_validator_test.dart
- command: `dart test test/zap/zap_validator_test.dart`
- exit: 0
- at: 2026-09-03T15:45:57.296466Z
- output:
```
00:00 +0: loading test/zap/zap_validator_test.dart
00:00 +0: ZapValidator — positive (U4) U4: the golden mission validates
00:00 +1: ZapValidator — positive (U4) U4: every golden example validates against its schema
00:00 +2: ZapValidator — missing required fields (U5) U5: a missing top-level required field is named by path
00:00 +3: ZapValidator — missing required fields (U5) U5: a missing nested field is named with its full path
00:00 +4: ZapValidator — missing required fields (U5) U5: a missing array-item field is named with its index
00:00 +5: ZapValidator — types, enums, patterns, bounds 
…[1731 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 142354c654142bacad0da2d190bb982048e1dafb5f16f66107ea9380ee03c3a1
- hash: c1bd1e322066d114645ddfda7e60008d76901b8be76ef63f903fc6fa08f5bf95

## Cycle: 071-zap-U5 (green)

- behavior: 071-zap-U5
- kind: green
- criterion: FR-007
- test: test/zap/zap_validator_test.dart
- command: `dart test test/zap/zap_validator_test.dart`
- exit: 0
- at: 2026-09-03T15:45:57.300020Z
- output:
```
00:00 +0: loading test/zap/zap_validator_test.dart
00:00 +0: ZapValidator — positive (U4) U4: the golden mission validates
00:00 +1: ZapValidator — positive (U4) U4: every golden example validates against its schema
00:00 +2: ZapValidator — missing required fields (U5) U5: a missing top-level required field is named by path
00:00 +3: ZapValidator — missing required fields (U5) U5: a missing nested field is named with its full path
00:00 +4: ZapValidator — missing required fields (U5) U5: a missing array-item field is named with its index
00:00 +5: ZapValidator — types, enums, patterns, bounds 
…[1731 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 5e4b2f9b060c9f0d1853fcc5b321c09920847aca234e0ab171ee348bc4903211
- hash: 6fbce266d568211b85150106edf5dceda951c33c029028e59859309353d48d9d

## Cycle: 071-zap-U6 (green)

- behavior: 071-zap-U6
- kind: green
- criterion: FR-007
- test: test/zap/zap_validator_test.dart
- command: `dart test test/zap/zap_validator_test.dart`
- exit: 0
- at: 2026-09-03T15:45:57.302210Z
- output:
```
00:00 +0: loading test/zap/zap_validator_test.dart
00:00 +0: ZapValidator — positive (U4) U4: the golden mission validates
00:00 +1: ZapValidator — positive (U4) U4: every golden example validates against its schema
00:00 +2: ZapValidator — missing required fields (U5) U5: a missing top-level required field is named by path
00:00 +3: ZapValidator — missing required fields (U5) U5: a missing nested field is named with its full path
00:00 +4: ZapValidator — missing required fields (U5) U5: a missing array-item field is named with its index
00:00 +5: ZapValidator — types, enums, patterns, bounds 
…[1731 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 445defaba084af98104177910a6c236fe356ae427644edd7407c1a2fdd653939
- hash: cf10988c3a58ef5103e5e1e03cd0cf9a83b6aa89e5cfdf4dbee31ed12232f33a

## Cycle: 071-zap-U7 (green)

- behavior: 071-zap-U7
- kind: green
- criterion: FR-007
- test: test/zap/zap_validator_test.dart
- command: `dart test test/zap/zap_validator_test.dart`
- exit: 0
- at: 2026-09-03T15:45:57.304590Z
- output:
```
00:00 +0: loading test/zap/zap_validator_test.dart
00:00 +0: ZapValidator — positive (U4) U4: the golden mission validates
00:00 +1: ZapValidator — positive (U4) U4: every golden example validates against its schema
00:00 +2: ZapValidator — missing required fields (U5) U5: a missing top-level required field is named by path
00:00 +3: ZapValidator — missing required fields (U5) U5: a missing nested field is named with its full path
00:00 +4: ZapValidator — missing required fields (U5) U5: a missing array-item field is named with its index
00:00 +5: ZapValidator — types, enums, patterns, bounds 
…[1731 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 664ac330af3d20535953b633221be550e4f845bfb4896a2a163a4e3d1d5c2e1d
- hash: 071a765ac56bf4226d1074c0b486bb58061c9c638c928f456997b828975b180b

## Cycle: 071-zap-U8 (green)

- behavior: 071-zap-U8
- kind: green
- criterion: FR-001..FR-005, FR-013
- test: test/zap/zap_message_test.dart
- command: `dart test test/zap/zap_message_test.dart`
- exit: 0
- at: 2026-09-03T15:45:58.220290Z
- output:
```
00:00 +0: loading test/zap/zap_message_test.dart
00:00 +0: ZapProtocol — NDJSON line codec (U8) U8: encodeLine/decodeLine round-trip a message map
00:00 +1: ZapProtocol — NDJSON line codec (U8) U8: garbage lines throw FormatException
00:00 +2: ZapProtocol — NDJSON line codec (U8) U8: the protocol version is 0.1 (the v0 slice)
00:00 +3: ZapMessage — typed round-trips (U9) U9: the golden mission round-trips with stable key order
00:00 +4: ZapMessage — typed round-trips (U9) U9: the golden evidence round-trips with stable key order
00:00 +5: ZapMessage — typed round-trips (U9) U9: the golden chec
…[1605 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 6cba77e8f9da548eff9f37df73889e2af6bf5befd4ca806763d552528d10aa15
- hash: ace4b8efb805cbada62f0b351233d325978b40d7ff1fc5d6dd76535bd53fc8b8

## Cycle: 071-zap-U9 (green)

- behavior: 071-zap-U9
- kind: green
- criterion: FR-001..FR-005, FR-013
- test: test/zap/zap_message_test.dart
- command: `dart test test/zap/zap_message_test.dart`
- exit: 0
- at: 2026-09-03T15:45:58.223057Z
- output:
```
00:00 +0: loading test/zap/zap_message_test.dart
00:00 +0: ZapProtocol — NDJSON line codec (U8) U8: encodeLine/decodeLine round-trip a message map
00:00 +1: ZapProtocol — NDJSON line codec (U8) U8: garbage lines throw FormatException
00:00 +2: ZapProtocol — NDJSON line codec (U8) U8: the protocol version is 0.1 (the v0 slice)
00:00 +3: ZapMessage — typed round-trips (U9) U9: the golden mission round-trips with stable key order
00:00 +4: ZapMessage — typed round-trips (U9) U9: the golden evidence round-trips with stable key order
00:00 +5: ZapMessage — typed round-trips (U9) U9: the golden chec
…[1605 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 4836f2fddc7095059b5b172973e7b940676e3fb9a07092b2afa83fc4307305ba
- hash: a1972013578dd2a55cfe2652a2ba5ab7350c288283a4f2fcb781421f6a583333

## Cycle: 071-zap-U10 (green)

- behavior: 071-zap-U10
- kind: green
- criterion: FR-001..FR-005, FR-013
- test: test/zap/zap_message_test.dart
- command: `dart test test/zap/zap_message_test.dart`
- exit: 0
- at: 2026-09-03T15:45:58.225122Z
- output:
```
00:00 +0: loading test/zap/zap_message_test.dart
00:00 +0: ZapProtocol — NDJSON line codec (U8) U8: encodeLine/decodeLine round-trip a message map
00:00 +1: ZapProtocol — NDJSON line codec (U8) U8: garbage lines throw FormatException
00:00 +2: ZapProtocol — NDJSON line codec (U8) U8: the protocol version is 0.1 (the v0 slice)
00:00 +3: ZapMessage — typed round-trips (U9) U9: the golden mission round-trips with stable key order
00:00 +4: ZapMessage — typed round-trips (U9) U9: the golden evidence round-trips with stable key order
00:00 +5: ZapMessage — typed round-trips (U9) U9: the golden chec
…[1605 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 23839dedcf166e88d8ab0f46aa381d33bc15f93b5d3275a35a53b96e36489005
- hash: 89c29ad55fa78e5d308a76dd965d294bd9ce60b25fcc2b282bcf1d6a10bfe23a

## Cycle: 071-zap-U11 (green)

- behavior: 071-zap-U11
- kind: green
- criterion: FR-001..FR-005, FR-013
- test: test/zap/zap_message_test.dart
- command: `dart test test/zap/zap_message_test.dart`
- exit: 0
- at: 2026-09-03T15:45:58.227636Z
- output:
```
00:00 +0: loading test/zap/zap_message_test.dart
00:00 +0: ZapProtocol — NDJSON line codec (U8) U8: encodeLine/decodeLine round-trip a message map
00:00 +1: ZapProtocol — NDJSON line codec (U8) U8: garbage lines throw FormatException
00:00 +2: ZapProtocol — NDJSON line codec (U8) U8: the protocol version is 0.1 (the v0 slice)
00:00 +3: ZapMessage — typed round-trips (U9) U9: the golden mission round-trips with stable key order
00:00 +4: ZapMessage — typed round-trips (U9) U9: the golden evidence round-trips with stable key order
00:00 +5: ZapMessage — typed round-trips (U9) U9: the golden chec
…[1605 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 1f783897ce2e9e21e483ad1a15f406be0d6517b878a248a7362d8aafe3d411b8
- hash: 7a418035d5cf3f9ee1f2bf9b117a81b8c8f1d11d8d99a410ee6afbeba6107850

## Cycle: 071-zap-U12 (green)

- behavior: 071-zap-U12
- kind: green
- criterion: FR-006, SC-001
- test: test/zap/zap_golden_test.dart
- command: `dart test test/zap/zap_golden_test.dart`
- exit: 0
- at: 2026-09-03T15:45:59.146891Z
- output:
```
00:00 +0: loading test/zap/zap_golden_test.dart
00:00 +0: U12: golden examples validate and round-trip
00:00 +1: A1: committed schemas and goldens match the code (no drift)
00:00 +2: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 492b3334a50166aebb06c5d5380ca6f31eaf2adbe342fdb0fffd5dc5c2cef7ea
- hash: 8b096e31c8bec39ed9709fe32f416a49ed84f486813b70e5bac851c72cd8d872

## Cycle: 071-zap-A1 (green)

- behavior: 071-zap-A1
- kind: green
- criterion: FR-006, SC-001
- test: test/zap/zap_golden_test.dart
- command: `dart test test/zap/zap_golden_test.dart`
- exit: 0
- at: 2026-09-03T15:45:59.153814Z
- output:
```
00:00 +0: loading test/zap/zap_golden_test.dart
00:00 +0: U12: golden examples validate and round-trip
00:00 +1: A1: committed schemas and goldens match the code (no drift)
00:00 +2: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: b85cff97bc170edf90564182688cc0f41960fd289cb1c9310ea208554ace5f69
- hash: afdebf3b97ee8371b1748cffd9137405e3f5623c1c4457df642d7aafcbbd9177

## Cycle: 071-zap-U13 (green)

- behavior: 071-zap-U13
- kind: green
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 0
- at: 2026-09-03T15:46:01.303358Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0: ZapHost — happy path (U13) U13: a clean mission produces evidence and a verified receipt
00:00 +1: ZapHost — happy path (U13) U13: later missions continue the session (cumulative chain)
00:00 +2: ZapHost — gates reject BEFORE execution (U14) U14: a mission whose steps exceed the budget is rejected
00:00 +3: ZapHost — gates reject BEFORE execution (U14) U14: cumulative budget exhaustion across missions
00:00 +4: ZapHost — gates reject BEFORE execution (U14) U14: a later mission cannot ESCALATE the budget
00:00 +5: ZapHost — gates reject BE
…[2042 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 263c713724543ab857a41d7c4ca20513247407bdf47d0b467cb9bdc1ec1284a4
- hash: e5178054b0d4c15253e0b8d31328b2c1a54e99b8a33055ba03a5efa45dab41d3

## Cycle: 071-zap-U14 (green)

- behavior: 071-zap-U14
- kind: green
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 0
- at: 2026-09-03T15:46:01.306251Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0: ZapHost — happy path (U13) U13: a clean mission produces evidence and a verified receipt
00:00 +1: ZapHost — happy path (U13) U13: later missions continue the session (cumulative chain)
00:00 +2: ZapHost — gates reject BEFORE execution (U14) U14: a mission whose steps exceed the budget is rejected
00:00 +3: ZapHost — gates reject BEFORE execution (U14) U14: cumulative budget exhaustion across missions
00:00 +4: ZapHost — gates reject BEFORE execution (U14) U14: a later mission cannot ESCALATE the budget
00:00 +5: ZapHost — gates reject BE
…[2042 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 5bcba855a85ec550ffb526d143d10340994e38e407102cc210ffd4ec52003fce
- hash: 504a3c1c2bb998679d0934756edf959ff9df7d637a633b543ac37b0b3e877999

## Cycle: 071-zap-U15 (green)

- behavior: 071-zap-U15
- kind: green
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 0
- at: 2026-09-03T15:46:01.308387Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0: ZapHost — happy path (U13) U13: a clean mission produces evidence and a verified receipt
00:00 +1: ZapHost — happy path (U13) U13: later missions continue the session (cumulative chain)
00:00 +2: ZapHost — gates reject BEFORE execution (U14) U14: a mission whose steps exceed the budget is rejected
00:00 +3: ZapHost — gates reject BEFORE execution (U14) U14: cumulative budget exhaustion across missions
00:00 +4: ZapHost — gates reject BEFORE execution (U14) U14: a later mission cannot ESCALATE the budget
00:00 +5: ZapHost — gates reject BE
…[2042 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 742fbbb5fe2f59546e7af3b6a6b616ab114a58b6921e832254db2032c9f9db05
- hash: 90d315784db9cfc3ae32c9f74a9b207ae90b20ee983b8fd36c83a86838cb6c02

## Cycle: 071-zap-U16 (green)

- behavior: 071-zap-U16
- kind: green
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 0
- at: 2026-09-03T15:46:01.311230Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0: ZapHost — happy path (U13) U13: a clean mission produces evidence and a verified receipt
00:00 +1: ZapHost — happy path (U13) U13: later missions continue the session (cumulative chain)
00:00 +2: ZapHost — gates reject BEFORE execution (U14) U14: a mission whose steps exceed the budget is rejected
00:00 +3: ZapHost — gates reject BEFORE execution (U14) U14: cumulative budget exhaustion across missions
00:00 +4: ZapHost — gates reject BEFORE execution (U14) U14: a later mission cannot ESCALATE the budget
00:00 +5: ZapHost — gates reject BE
…[2042 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 20efb86f62181bf8e990cafa07c109b7cefb4cfbbc4b97df7326e9d6aeff98bb
- hash: 5751139ad676771028851d0fabef9b6ca0b9230d5b67308941afd6280b631999

## Cycle: 071-zap-U17 (green)

- behavior: 071-zap-U17
- kind: green
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 0
- at: 2026-09-03T15:46:01.313349Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0: ZapHost — happy path (U13) U13: a clean mission produces evidence and a verified receipt
00:00 +1: ZapHost — happy path (U13) U13: later missions continue the session (cumulative chain)
00:00 +2: ZapHost — gates reject BEFORE execution (U14) U14: a mission whose steps exceed the budget is rejected
00:00 +3: ZapHost — gates reject BEFORE execution (U14) U14: cumulative budget exhaustion across missions
00:00 +4: ZapHost — gates reject BEFORE execution (U14) U14: a later mission cannot ESCALATE the budget
00:00 +5: ZapHost — gates reject BE
…[2042 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 4ecabd6ec318bd8d803537e762f6a05383f7106dc170771b8340e5c9b33d882a
- hash: 20d8948c8d40755ff0424f05e3f5f442f3de6b0e750a332b4f11ad61f6bcd110

## Cycle: 071-zap-U18 (green)

- behavior: 071-zap-U18
- kind: green
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 0
- at: 2026-09-03T15:46:01.315533Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0: ZapHost — happy path (U13) U13: a clean mission produces evidence and a verified receipt
00:00 +1: ZapHost — happy path (U13) U13: later missions continue the session (cumulative chain)
00:00 +2: ZapHost — gates reject BEFORE execution (U14) U14: a mission whose steps exceed the budget is rejected
00:00 +3: ZapHost — gates reject BEFORE execution (U14) U14: cumulative budget exhaustion across missions
00:00 +4: ZapHost — gates reject BEFORE execution (U14) U14: a later mission cannot ESCALATE the budget
00:00 +5: ZapHost — gates reject BE
…[2042 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: fe1cb25ce988f22b5f8d3322f97a8fc5cb9796ea7c3d41dbc477b7736d016fa5
- hash: 92e5c2a1dd0b951359ecc89127659c981dcfaf0471576a13b3dc99f15cb6caf8

## Cycle: 071-zap-A7 (green)

- behavior: 071-zap-A7
- kind: green
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 0
- at: 2026-09-03T15:46:01.317576Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0: ZapHost — happy path (U13) U13: a clean mission produces evidence and a verified receipt
00:00 +1: ZapHost — happy path (U13) U13: later missions continue the session (cumulative chain)
00:00 +2: ZapHost — gates reject BEFORE execution (U14) U14: a mission whose steps exceed the budget is rejected
00:00 +3: ZapHost — gates reject BEFORE execution (U14) U14: cumulative budget exhaustion across missions
00:00 +4: ZapHost — gates reject BEFORE execution (U14) U14: a later mission cannot ESCALATE the budget
00:00 +5: ZapHost — gates reject BE
…[2042 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 75b62230e44c8592da4078d5aeed1db68b3a6bbf164cbe74e2d442dae831fe1d
- hash: c960247da63807d539f1a774190ba30bbd59d05604f2787b41192712ea9a75c9

## Cycle: 071-zap-A8 (green)

- behavior: 071-zap-A8
- kind: green
- criterion: FR-004, FR-005, FR-009..FR-012, FR-016, SC-005
- test: test/zap/zap_host_test.dart
- command: `dart test test/zap/zap_host_test.dart`
- exit: 0
- at: 2026-09-03T15:46:01.319516Z
- output:
```
00:00 +0: loading test/zap/zap_host_test.dart
00:00 +0: ZapHost — happy path (U13) U13: a clean mission produces evidence and a verified receipt
00:00 +1: ZapHost — happy path (U13) U13: later missions continue the session (cumulative chain)
00:00 +2: ZapHost — gates reject BEFORE execution (U14) U14: a mission whose steps exceed the budget is rejected
00:00 +3: ZapHost — gates reject BEFORE execution (U14) U14: cumulative budget exhaustion across missions
00:00 +4: ZapHost — gates reject BEFORE execution (U14) U14: a later mission cannot ESCALATE the budget
00:00 +5: ZapHost — gates reject BE
…[2042 chars total]
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 10f6a1bd23c2560f80a0c785281c526258ab302ffe551f08174e703581837ebd
- hash: d09e3aac065cc57c720be38a067228d7aac1fff7ce60c47a369c43fcf9a742f4

## Cycle: 071-zap-U19 (green)

- behavior: 071-zap-U19
- kind: green
- criterion: FR-014
- test: test/zap/zap_client_test.dart
- command: `dart test test/zap/zap_client_test.dart`
- exit: 0
- at: 2026-09-03T15:46:02.309385Z
- output:
```
00:00 +0: loading test/zap/zap_client_test.dart
00:00 +0: U19: the reference client submits, checkpoints, and verifies receipts
00:00 +1: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: b0282d0805932428dea82a61b2c23abc142b280060e8cea8c0bf5842eb6553c5
- hash: 23bcd54496d48a5d92a61580ec09e92610c2458301c6478d82300fa3875a57c0

## Cycle: 071-zap-A2 (green)

- behavior: 071-zap-A2
- kind: green
- criterion: FR-006, FR-008, SC-002
- test: test/zap/zap_conformance_test.dart
- command: `dart test test/zap/zap_conformance_test.dart`
- exit: 0
- at: 2026-09-03T15:46:10.885445Z
- output:
```
00:00 +0: loading test/zap/zap_conformance_test.dart
00:00 +0: zfa zap conform A2: zfa zap conform passes with the machine summary line
00:00 +1: zfa zap conform A3: --format json emits one verdict object
00:00 +2: zfa zap conform A3: a failing drift check flips the verdict and the exit code
00:00 +3: zfa zap schema U21: --type mission prints the draft-07 schema
00:00 +4: zfa zap schema U21: --export writes the five schemas + four goldens
00:00 +5: zfa zap schema U21: an unknown type is a usage error
00:00 +6: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 5ca4fad460821e022467ea3aa9afec292e90e41b545de7b1ca1d001419b4925d
- hash: bf412dfd8d2691b718fa15e2f846c99db24cfe464272d15c627992822d33da53

## Cycle: 071-zap-A3 (green)

- behavior: 071-zap-A3
- kind: green
- criterion: FR-006, FR-008, SC-002
- test: test/zap/zap_conformance_test.dart
- command: `dart test test/zap/zap_conformance_test.dart`
- exit: 0
- at: 2026-09-03T15:46:10.888573Z
- output:
```
00:00 +0: loading test/zap/zap_conformance_test.dart
00:00 +0: zfa zap conform A2: zfa zap conform passes with the machine summary line
00:00 +1: zfa zap conform A3: --format json emits one verdict object
00:00 +2: zfa zap conform A3: a failing drift check flips the verdict and the exit code
00:00 +3: zfa zap schema U21: --type mission prints the draft-07 schema
00:00 +4: zfa zap schema U21: --export writes the five schemas + four goldens
00:00 +5: zfa zap schema U21: an unknown type is a usage error
00:00 +6: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: dd7d2a1d57a81fdae6b654f5a59d461fe28553798f3264b998579b16d6a5cc7f
- hash: 5f92c66ef872f2608d73af19702578a6661293b061e25dfba6b8e8424e3a1028

## Cycle: 071-zap-U21 (green)

- behavior: 071-zap-U21
- kind: green
- criterion: FR-006, FR-008, SC-002
- test: test/zap/zap_conformance_test.dart
- command: `dart test test/zap/zap_conformance_test.dart`
- exit: 0
- at: 2026-09-03T15:46:10.890713Z
- output:
```
00:00 +0: loading test/zap/zap_conformance_test.dart
00:00 +0: zfa zap conform A2: zfa zap conform passes with the machine summary line
00:00 +1: zfa zap conform A3: --format json emits one verdict object
00:00 +2: zfa zap conform A3: a failing drift check flips the verdict and the exit code
00:00 +3: zfa zap schema U21: --type mission prints the draft-07 schema
00:00 +4: zfa zap schema U21: --export writes the five schemas + four goldens
00:00 +5: zfa zap schema U21: an unknown type is a usage error
00:00 +6: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 9cb57997056ee2ff7ae8008c6eb7bda010602f11d58552e81b926b64bc8ebb14
- hash: f3c205a63e128b94614355c3bdc73b4392fa3685bd5f665fa28cd5bef5f2c561

## Cycle: 071-zap-U20 (green)

- behavior: 071-zap-U20
- kind: green
- criterion: FR-008, FR-009
- test: test/zap/zap_command_smoke_test.dart
- command: `dart test test/zap/zap_command_smoke_test.dart`
- exit: 0
- at: 2026-09-03T15:46:13.223890Z
- output:
```
00:00 +0: loading test/zap/zap_command_smoke_test.dart
00:00 +0: U20: zfa zap --help lists the three subcommands
00:00 +1: U20: bare `zfa zap` prints its usage (no subcommand)
00:00 +2: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 5ef2c5454753d750304dc9f64feb6af2ebd97f03c55d6c49ceaa3678bbd14c62
- hash: 9fe2c2cce70e8555f37596216784f98bb81e384e966f6c9f871fcdc24a4ad9ad

## Cycle: 071-zap-A4 (green)

- behavior: 071-zap-A4
- kind: green
- criterion: FR-015, FR-017, SC-003, SC-004
- test: test/zap/zap_interop_test.dart
- command: `dart test test/zap/zap_interop_test.dart`
- exit: 0
- at: 2026-09-03T15:47:29.887217Z
- output:
```
00:00 +0: loading test/zap/zap_interop_test.dart
00:00 +0: (setUpAll)
00:00 +0: A4: reference client drives the real zfa zap serve subprocess
00:18 +1: A5: foreign client drives a full TDD loop end-to-end
00:36 +2: A6: two independent clients, same unmodified host
01:14 +3: (tearDownAll)
01:14 +3: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: b759f7548a1608cdb6a789abd2cacd8f667215ece744d1d84e98c662644a0301
- hash: e7372b28d477a0d1fd28e88d8a7c2405fd1b9770d933834a324bb8fe97e606e3

## Cycle: 071-zap-A5 (green)

- behavior: 071-zap-A5
- kind: green
- criterion: FR-015, FR-017, SC-003, SC-004
- test: test/zap/zap_interop_test.dart
- command: `dart test test/zap/zap_interop_test.dart`
- exit: 0
- at: 2026-09-03T15:47:29.890474Z
- output:
```
00:00 +0: loading test/zap/zap_interop_test.dart
00:00 +0: (setUpAll)
00:00 +0: A4: reference client drives the real zfa zap serve subprocess
00:18 +1: A5: foreign client drives a full TDD loop end-to-end
00:36 +2: A6: two independent clients, same unmodified host
01:14 +3: (tearDownAll)
01:14 +3: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: b1d9995f5050b07981d8003b30a05e2680440617bba40be8fdf736e772b84630
- hash: dc63accf20773615dad130e9b9debac8e7a6d4d3114b058571c08c012bb5033e

## Cycle: 071-zap-A6 (green)

- behavior: 071-zap-A6
- kind: green
- criterion: FR-015, FR-017, SC-003, SC-004
- test: test/zap/zap_interop_test.dart
- command: `dart test test/zap/zap_interop_test.dart`
- exit: 0
- at: 2026-09-03T15:47:29.892924Z
- output:
```
00:00 +0: loading test/zap/zap_interop_test.dart
00:00 +0: (setUpAll)
00:00 +0: A4: reference client drives the real zfa zap serve subprocess
00:18 +1: A5: foreign client drives a full TDD loop end-to-end
00:36 +2: A6: two independent clients, same unmodified host
01:14 +3: (tearDownAll)
01:14 +3: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 015e2d0a8181e4fbed87a4619144ef495f481f0cf1fa6a4b975c88645170812c
- hash: 7e92e3ee1e964080bafe91d0782f8de24b55df15f3f73244eea32f3d3d7ae15f

