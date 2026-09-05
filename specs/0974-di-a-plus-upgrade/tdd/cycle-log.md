# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- evidence: expect(deadFile.existsSync(), isFalse) — dead_command_gone_test.dart:31
- criterion: AC-1
- test: test/plugins/di/dead_command_gone_test.dart
- command: `dart test test/plugins/di/dead_command_gone_test.dart`
- exit: 1
- at: 2026-09-04T19:48:09Z
- output:
```
00:00 +0: loading test/plugins/di/dead_command_gone_test.dart
00:00 +0: A1: the 427-LOC dead command file is deleted from the tree
00:00 +0 -1: A1: the 427-LOC dead command file is deleted from the tree [E]
  Expected: false
    Actual: <true>
  the dead command must be deleted (issue #974 order 1)
  
  package:matcher                                   expect
  test/plugins/di/dead_command_gone_test.dart 31:5  main.<fn>
  
00:00 +0 -1: U1: no source under lib/ references the dead command file
00:00 +1 -1: A1b: the dead standalone command class is gone from lib/src/commands
00:00 +1 -2: A1b: the dead standalone command class is gone from lib/src/commands [E]
  Expected: empty
    Actual: ['/home/z/my-project/zuraffa/lib/src/commands/di_command.dart']
  the dead class is still declared in: /home/z/my-project/zuraffa/lib/src/commands/di_command.dart
  
  package:matcher                                   expect
  test/plugins/di/dead_command_gone_test.dart 86:7  main.<fn>
  
00:00 +1 -2: Some tests failed.

Failing tests:
  test/plugins/di/dead_command_gone_test.dart: A1: the 427-LOC dead command file is deleted from the tree
  test/plugins/di/dead_command_gone_test.dart: A1b: the dead standalone command class is gone from lib/src/commands
```

- schema: 1
- prev-hash: genesis
- hash: ccf2bd14943ff9692e96bf2e611eee137d7b62b7616c930f97c80372fc46e8df

## Cycle: A1 (green)

- behavior: A1
- kind: green
- criterion: AC-1
- test: test/plugins/di/dead_command_gone_test.dart
- command: `dart test test/plugins/di/dead_command_gone_test.dart`
- exit: 0
- at: 2026-09-04T19:48:19Z
- output:
```
00:00 +0: loading test/plugins/di/dead_command_gone_test.dart
00:00 +0: A1: the 427-LOC dead command file is deleted from the tree
00:00 +1: U1: no source under lib/ references the dead command file
00:00 +2: A1b: the dead standalone command class is gone from lib/src/commands
00:00 +3: All tests passed!
```
- generation:
  - step: git rm lib/src/commands/di_command.dart
    exit: 0
    purpose: implement behavior A1
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: ccf2bd14943ff9692e96bf2e611eee137d7b62b7616c930f97c80372fc46e8df
- hash: 730bd36c378f5eb9f3467a106862b87ade8b4c6ee5b9d8878bc5c7f562f8194d

## Cycle: A2 (red)

- behavior: A2
- kind: red
- classification: compileError
- evidence: No named parameter / Method not found: 'DiVerifyCapability'
- criterion: AC-2
- test: test/plugins/di/di_verify_test.dart
- command: `dart test test/plugins/di/di_verify_test.dart`
- exit: 1
- at: 2026-09-04T19:48:14Z
- output:
```
00:00 +0: loading test/plugins/di/di_verify_test.dart
00:00 +0 -1: loading test/plugins/di/di_verify_test.dart [E]
  Failed to load "test/plugins/di/di_verify_test.dart":
  test/plugins/di/di_verify_test.dart:7:8: Error: Error when reading 'lib/src/plugins/di/capabilities/verify_capability.dart': No such file or directory
  import 'package:zuraffa/src/plugins/di/capabilities/verify_capability.dart';
         ^
  test/plugins/di/di_verify_test.dart:34:3: Error: 'DiVerifyCapability' isn't a type.
    DiVerifyCapability buildCapability() =>
    ^^^^^^^^^^^^^^^^^^
  test/plugins/di/di_verify_test.dart:35:7: Error: Method not found: 'DiVerifyCapability'.
        DiVerifyCapability(buildPlugin(), projectRoot: projectRoot);
        ^^^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/plugins/di/di_verify_test.dart: loading test/plugins/di/di_verify_test.dart
```

- schema: 1
- prev-hash: genesis
- hash: aea9451a5a3a8999bbd57a9380f42928744b1630617c738fad0578fb4b45785a

## Cycle: A2 (green)

- behavior: A2
- kind: green
- criterion: AC-2
- test: test/plugins/di/di_verify_test.dart
- command: `dart test test/plugins/di/di_verify_test.dart`
- exit: 0
- at: 2026-09-04T19:48:25Z
- output:
```
00:00 +0: loading test/plugins/di/di_verify_test.dart
00:00 +0: A2 positive: clean registrations verify green
00:00 +1: A2 negative: dangling getIt<Missing>() registration fails with fix hint
00:00 +2: U2: a missing di/ tree verifies green (nothing to check)
00:00 +3: U3: a dead import URI in a DI file is reported as a finding
00:00 +4: A2 wiring: the verify capability is registered as a di subcommand
00:00 +5: All tests passed!
```
- generation:
  - step: implement lib/src/plugins/di/capabilities/verify_capability.dart
    exit: 0
    purpose: implement behavior A2
  - step: register DiVerifyCapability in DiPlugin.capabilities
    exit: 0
    purpose: implement behavior A2
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: aea9451a5a3a8999bbd57a9380f42928744b1630617c738fad0578fb4b45785a
- hash: 33d4854d0fc09bcebda3193e2938e022032e40e120049de55b8acdf82e49387b

## Cycle: A3 (red)

- behavior: A3
- kind: red
- classification: compileError
- evidence: No named parameter with the name 'projectRoot' (receipt wiring absent)
- criterion: AC-3
- test: test/plugins/di/di_receipts_test.dart
- command: `dart test test/plugins/di/di_receipts_test.dart`
- exit: 1
- at: 2026-09-04T19:48:16Z
- output:
```
00:00 +0: loading test/plugins/di/di_receipts_test.dart
00:00 +0 -1: loading test/plugins/di/di_receipts_test.dart [E]
  Failed to load "test/plugins/di/di_receipts_test.dart":
  test/plugins/di/di_receipts_test.dart:49:51: Error: No named parameter with the name 'projectRoot'.
      final capability = CreateDiCapability(plugin, projectRoot: projectRoot);
                                                    ^^^^^^^^^^^
  lib/src/plugins/di/capabilities/create_di_capability.dart:9:3: Context: Found this candidate, but the arguments don't match.
    CreateDiCapability(this.plugin);
    ^^^^^^^^^^^^^^^^^^
  test/plugins/di/di_receipts_test.dart:115:9: Error: No named parameter with the name 'projectRoot'.
          projectRoot: projectRoot,
          ^^^^^^^^^^^
  lib/src/plugins/di/capabilities/create_di_capability.dart:9:3: Context: Found this candidate, but the arguments don't match.
    CreateDiCapability(this.plugin);
    ^^^^^^^^^^^^^^^^^^
  test/plugins/di/di_receipts_test.dart:134:51: Error: No named parameter with the name 'projectRoot'.
      final capability = RegisterCapability(plugin, projectRoot: projectRoot);
                                                    ^^^^^^^^^^^
  lib/src/plugins/di/capabilities/register_capability.dart:12:3: Context: Found this candidate, but the arguments don't match.
    RegisterCapability(this.plugin);
    ^^^^^^^^^^^^^^^^^^
  test/plugins/di/di_receipts_test.dart:160:51: Error: No named parameter with the name 'projectRoot'.
      final capability = CreateDiCapability(plugin, projectRoot: projectRoot);
                                                    ^^^^^^^^^^^
  lib/src/plugins/di/capabilities/create_di_capability.dart:9:3: Context: Found this candidate, but the arguments don't match.
    CreateDiCapability(this.plugin);
    ^^^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/plugins/di/di_receipts_test.dart: loading test/plugins/di/di_receipts_test.dart
```

- schema: 1
- prev-hash: genesis
- hash: 24ceb014915afb3b5ae48ab5533368f4f036a16852197e3932dc4403a373ccb9

## Cycle: A3 (green)

- behavior: A3
- kind: green
- criterion: AC-3
- test: test/plugins/di/di_receipts_test.dart
- command: `dart test test/plugins/di/di_receipts_test.dart`
- exit: 0
- at: 2026-09-04T19:48:27Z
- output:
```
00:00 +0: loading test/plugins/di/di_receipts_test.dart
00:00 +0: A3: standalone di create appends a di-<target> receipt binding the written registrations and index
00:00 +1: A3b: zfa proof check (ProofChecker) is green after a standalone run
00:00 +2: U4: standalone di register also writes a receipt
00:00 +3: U5: dry-run and revert runs write no receipt
00:00 +4: All tests passed!
```
- generation:
  - step: implement lib/src/plugins/di/capabilities/di_receipt_writer.dart
    exit: 0
    purpose: implement behavior A3
  - step: wire receipt emission into Create/RegisterCapability.execute
    exit: 0
    purpose: implement behavior A3
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 24ceb014915afb3b5ae48ab5533368f4f036a16852197e3932dc4403a373ccb9
- hash: 4a02620c296d99122d7fb28411705806df95e184728a2f1a4b48f107b438a0ae

## Cycle: A4 (red)

- behavior: A4
- kind: red
- classification: compileError
- evidence: No named parameter with the name 'warnings' (verdicts hardwired to success:true)
- criterion: AC-4
- test: test/plugins/di/di_verdicts_test.dart
- command: `dart test test/plugins/di/di_verdicts_test.dart`
- exit: 1
- at: 2026-09-04T19:48:18Z
- output:
```
00:00 +0: loading test/plugins/di/di_verdicts_test.dart
00:00 +0 -1: loading test/plugins/di/di_verdicts_test.dart [E]
  Failed to load "test/plugins/di/di_verdicts_test.dart":
  test/plugins/di/di_verdicts_test.dart:173:7: Error: No named parameter with the name 'warnings'.
        warnings: [
        ^^^^^^^^
  lib/src/core/plugin_system/capability.dart:93:3: Context: Found this candidate, but the arguments don't match.
    ExecutionResult({
    ^^^^^^^^^^^^^^^
  test/plugins/di/di_verdicts_test.dart:125:16: Error: The getter 'warnings' isn't defined for the type 'ExecutionResult'.
   - 'ExecutionResult' is from 'package:zuraffa/src/core/plugin_system/capability.dart' ('lib/src/core/plugin_system/capability.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'warnings'.
          result.warnings,
                 ^^^^^^^^
  test/plugins/di/di_verdicts_test.dart:148:16: Error: The getter 'warnings' isn't defined for the type 'ExecutionResult'.
   - 'ExecutionResult' is from 'package:zuraffa/src/core/plugin_system/capability.dart' ('lib/src/core/plugin_system/capability.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'warnings'.
          second.warnings,
                 ^^^^^^^^
  test/plugins/di/di_verdicts_test.dart:152:36: Error: The getter 'warnings' isn't defined for the type 'ExecutionResult'.
   - 'ExecutionResult' is from 'package:zuraffa/src/core/plugin_system/capability.dart' ('lib/src/core/plugin_system/capability.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'warnings'.
        for (final warning in second.warnings) {
                                     ^^^^^^^^
  test/plugins/di/di_verdicts_test.dart:159:16: Error: The getter 'warnings' isn't defined for the type 'ExecutionResult'.
   - 'ExecutionResult' is from 'package:zuraffa/src/core/plugin_system/capability.dart' ('lib/src/core/plugin_system/capability.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'warnings'.
          second.warnings.any(
                 ^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/plugins/di/di_verdicts_test.dart: loading test/plugins/di/di_verdicts_test.dart
```

- schema: 1
- prev-hash: genesis
- hash: b626b0447eacb070226a9bfd037cf5a3c9b1a99442041b303bc5a4c12c9f63a9

## Cycle: A4 (green)

- behavior: A4
- kind: green
- criterion: AC-4
- test: test/plugins/di/di_verdicts_test.dart
- command: `dart test test/plugins/di/di_verdicts_test.dart`
- exit: 0
- at: 2026-09-04T19:48:29Z
- output:
```
00:00 +0: loading test/plugins/di/di_verdicts_test.dart
00:00 +0: A4: a forced generation failure returns success: false
00:00 +1: A4b: successful generation still returns success: true (no false negatives)
00:00 +2: A4c: skipped files surface as structured {target, reason} warnings
00:00 +3: U6: ExecutionResult serializes structured warnings in toJson()
00:00 +4: All tests passed!
```
- generation:
  - step: ExecutionResult gains structured warnings {target, reason}
    exit: 0
    purpose: implement behavior A4
  - step: try/catch verdicts in both capabilities; service_locator skip reported
    exit: 0
    purpose: implement behavior A4
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: b626b0447eacb070226a9bfd037cf5a3c9b1a99442041b303bc5a4c12c9f63a9
- hash: d600530652050c219622b95ca506a305ca90b22341bf7705570fa18429ba1564

