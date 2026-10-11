# TDD Test List — Spec 1513

Red pre-fix: B1, B3, B4, B7 red (hardcoded `package:test` / relative subject
import); B2, B5, B6, B8 guards green on the current binary.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | ContractTestWriter(flutterTest: true) emits the flutter_test import (parseable template) | FR-1 / SC-1 | test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart |
| B2 | Default ContractTestWriter stays on package:test (guard) | FR-1 / SC-1 | test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart |
| B3 | Unparseable contract template honors flutterTest (true → flutter_test; default → package:test) | FR-4 / SC-4 | test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart |
| B4 | Contract subject import resolves a package: URI when the subject is under lib/ | FR-2 / SC-2 | test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart |
| B5 | Relative fallback kept when the subject is outside lib/ (or no pubspec) | FR-2 / SC-2 | test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart |
| B6 | packageSubjectImportFor direct pins (under-lib → package URI; no pubspec → null; outside lib → null) | FR-2 / SC-2 | test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart |
| B7 | _writersFor threads flutterTest: gen contract:A1 on a flutter-dependency fixture emits flutter_test; pure-Dart fixture keeps package:test | FR-3 / SC-3 | test/plugins/tdd/commands/bug_1513_contract_writers_threading_test.dart |
| B8 | Byte-stability: default render for the no-pubspec fixture shape is byte-identical to the pre-fix output (golden) | FR-5 / SC-5 | test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart |

## Red protocol

```
dart test test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart
dart test test/plugins/tdd/commands/bug_1513_contract_writers_threading_test.dart
```
