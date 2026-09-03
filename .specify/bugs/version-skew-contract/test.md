# Bug Test: version-skew-contract (issue #911)

- **Slug**: version-skew-contract
- **Verdict**: verified

## Evidence

1. **Acceptance Test**: `dart test test/plugins/tdd/bug_911_version_skew_contract_test.dart`
   - A1: `lib/zuraffa.dart` exports `PersistenceTestHarness` and `TestClock` — PASSED
   - A2: `zfa tdd doctor` detects unexported symbols and prescribes `upgrade-runtime` — PASSED
   - A3: `zfa tdd doctor` passes (healthy) when all imported symbols exist in barrel — PASSED

2. **Scoped Test Suite**: `dart test test/plugins/tdd/`
   - 733 passed, 1 skipped, 0 failed.

3. **Analyzer**: `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
   - 0 issues found.
