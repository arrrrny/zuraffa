# Feature Specification: Generator/runtime version-skew contract

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `fix/version-skew-contract`

**Created**: 2026-09-03

**Status**: Approved

**Input**: Bug issue #911 (Part of #908): Generator/runtime version-skew contract: generated code must compile against PUBLISHED zuraffa. Generated persistence tests import `package:zuraffa/zuraffa.dart` referencing `PersistenceTestHarness` and `TestClock`.

## User Scenarios & Testing

### User Story 1 - Doctor import-resolution drift check (Priority: P1)

A developer runs `zfa tdd doctor <feature>` in a project where generated tests import `package:zuraffa/zuraffa.dart` symbols. If any imported symbols from `package:zuraffa` cannot be resolved in the project's resolved `package:zuraffa` package (or barrel exports), `zfa tdd doctor` flags an `import-resolution` drift with prescription `upgrade-runtime` and exit code 1.

**Acceptance Scenarios**:

1. **Given** a feature with generated tests importing symbols exported by `package:zuraffa/zuraffa.dart` (`PersistenceTestHarness`, `TestClock`), **When** `zfa tdd doctor` runs, **Then** doctor checks exports and reports healthy (exit 0) when all symbols resolve.
2. **Given** a feature with a generated test importing an unexported symbol from `package:zuraffa/zuraffa.dart`, **When** `zfa tdd doctor` runs, **Then** doctor reports drift with verdict `drift`, prescription `upgrade-runtime`, and exit 1.

### User Story 2 - Barrel Export Guarantee (Priority: P1)

The zuraffa package barrel (`lib/zuraffa.dart`) must explicitly export `src/testing/persistence_test_harness.dart` so `PersistenceTestHarness` and `TestClock` resolve when consumers import `package:zuraffa/zuraffa.dart`.

**Acceptance Scenarios**:

1. **Given** `package:zuraffa/zuraffa.dart`, **When** inspected for public testing exports, **Then** `PersistenceTestHarness` and `TestClock` are exported and accessible without importing `src/`.

## Requirements

- **FR-001**: `lib/zuraffa.dart` MUST re-export `src/testing/persistence_test_harness.dart`.
- **FR-002**: `zfa tdd doctor <feature>` MUST verify that symbols imported from `package:zuraffa/zuraffa.dart` by registered test artifacts exist in the resolved `package:zuraffa` barrel.
- **FR-003**: When missing symbols are detected in registered test files, `zfa tdd doctor` MUST prescribe `upgrade-runtime` with a fix line recommending `dart pub upgrade zuraffa` or updating `pubspec.yaml`.
