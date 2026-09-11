# TDD Cycle Log — Spec 1513 (append-only)

## Cycle C1 — the contract test templates honor flutterTest + the package subject import

- **RED** (pre-fix, recorded before the fix commit):
  - `dart test test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart`
    → load error (the missing API surface itself):
      `No named parameter with the name 'flutterTest'` at
      `ContractTestWriter(flutterTest: ...)` (line 78) and
      `Member not found: 'BehaviorTestWriter.packageSubjectImportFor'`
      (lines 229/239/252). B1–B6, B8 unrunnable until the API exists.
  - `dart test test/plugins/tdd/commands/bug_1513_contract_writers_threading_test.dart`
    → B7a **assertion red** (honest): the generated `contract_a1_test.dart`
      contains `import 'package:test/test.dart';` and no flutter_test import
      — the exact `Couldn't resolve the package 'test'` defect #1513 reports,
      reproduced end to end through `zfa tdd plan` + `zfa tdd gen contract:A1`
      on a `dependencies: flutter:` fixture. B7b guard green (pure-Dart
      default already emits the plain import).
- **GREEN**: implement FR-1..FR-4 —
  - `contract_test_writer.dart`: `flutterTest` field (default false) +
    `_testImport` getter; subject import resolved through the promoted
    static with the legacy relative fallback; both templates (parseable +
    unparseable) interpolate the resolved imports.
  - `behavior_test_writer.dart`: `_packageSubjectImport` → public static
    `packageSubjectImportFor` (instance call site updated, behavior equal).
  - `gen_command.dart`: `_writersFor` contract branch threads `flutterTest`.
- **Result**: pending green run.
