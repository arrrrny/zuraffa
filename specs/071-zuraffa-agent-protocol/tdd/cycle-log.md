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
