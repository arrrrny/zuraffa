# Bug Fix: version-skew-contract (issue #911)

- **Slug**: version-skew-contract
- **Branch**: `fix/version-skew-contract`
- **Issue**: #911
- **Status**: applied

## Summary

1. Ensured `PersistenceTestHarness` and `TestClock` are exported in the main `lib/zuraffa.dart` barrel file.
2. Added `ImportResolutionChecker` in `lib/src/plugins/tdd/services/import_resolution_checker.dart` to verify that generated tests importing `package:zuraffa/zuraffa.dart` only reference symbols exported by the public barrel.
3. Added import-resolution and version-skew drift checks to `zfa tdd doctor` (`lib/src/plugins/tdd/commands/doctor_command.dart`), diagnosing unexported symbols with the `upgrade-runtime` prescription and `dart pub upgrade zuraffa` fix line.
4. Added test suite `test/plugins/tdd/bug_911_version_skew_contract_test.dart` verifying all 3 acceptance behaviors (A1, A2, A3).

## TDD Artifacts

- Spec: `.specify/bugs/version-skew-contract/spec.md`
- Test List: `.specify/bugs/version-skew-contract/tdd/test-list.md`
- Tasks: `.specify/bugs/version-skew-contract/tasks.md`
- Test suite: `test/plugins/tdd/bug_911_version_skew_contract_test.dart`

## Verification

- `dart test test/plugins/tdd/bug_911_version_skew_contract_test.dart` -> All 3 tests passed.
- Scoped suite: `dart test test/plugins/tdd/` -> 733 passed, 1 skipped, 0 failed.
- Static analysis: `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/` -> Clean (0 issues).
