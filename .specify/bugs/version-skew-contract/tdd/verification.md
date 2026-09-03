# Verification Report: version-skew-contract (issue #911)

- **Slug**: version-skew-contract
- **Verdict**: verified
- **Evidence**:
  - `dart test test/plugins/tdd/bug_911_version_skew_contract_test.dart` passes (3/3).
  - `dart test test/plugins/tdd/` full scoped suite passes (733/734, 1 skipped).
  - `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/` reports 0 issues.
