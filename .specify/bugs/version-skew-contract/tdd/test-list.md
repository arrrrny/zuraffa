# Test List: version-skew-contract (issue #911)

## Acceptance Behaviors

- [ ] A1: `lib/zuraffa.dart` exports `PersistenceTestHarness` and `TestClock` (FR-001)
- [ ] A2: `zfa tdd doctor` detects missing/unexported `package:zuraffa` symbols in test files and prescribes `upgrade-runtime` with exit 1 (FR-002, FR-003)
- [ ] A3: `zfa tdd doctor` passes (exit 0, healthy) when all `package:zuraffa` imported symbols exist in the barrel (FR-002)
