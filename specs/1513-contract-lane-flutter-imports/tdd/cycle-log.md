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
- **GREEN** (all suites run after the fix):
  - `dart test test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart`
    → `+10: All tests passed!` (B1–B6, B8; B8 compares byte-for-byte against
      the committed pre-fix golden
      `test/fixtures/baseline_outputs/bug_1513_contract_default_render.txt`
      — the pure-Dart default is unchanged).
  - `dart test test/plugins/tdd/commands/bug_1513_contract_writers_threading_test.dart`
    → `+2: All tests passed!` (B7a flutter fixture emits flutter_test +
      package subject URI; B7b pure-Dart fixture keeps package:test).
  - Neighbors (consumers of the touched surfaces):
    `contract_kind_1007_test.dart` (the relative-import pin — its fixture
    has no pubspec, the promoted helper returns null, the relative fallback
    keeps it green), `bug_1443_void_contract_seam_test.dart`,
    `bug_1363_contract_stub_dup_args_test.dart`,
    `bug_1458_pubspec_comment_flutter_test.dart` → `+29: All tests passed!`;
    `gen_command_test.dart`, `gen_namespacing_827_test.dart`,
    `bug_912_widget_shell_and_finders_test.dart` → `+8: All tests passed!`.
  - `dart analyze` on the three changed lib files + the two new test files →
    `No issues found!`; `dart format` applied (3 files reformatted).
- **Mutation sampling** (rubric fallback, no CI mutation gate):
  - M1 — threading removed (`ContractTestWriter(flutterTest: flutterTest)`
    → `const ContractTestWriter()` in `_writersFor`): B7a RED → **killed**.
  - M2 — default drift is covered by B8's byte-for-byte golden (any change
    to the default render surface fails SC-5 immediately).
- **Refactor**: none needed — the fix is the promotion itself (one source of
  truth); templates interpolate shared getters, no duplication left.
