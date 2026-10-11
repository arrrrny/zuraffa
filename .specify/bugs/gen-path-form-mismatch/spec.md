# Bug Spec: TDD registry path-form mismatch

## Summary

TDD artifact registry paths must resolve consistently whether they are stored as project-relative or absolute paths. Behavior regeneration must not refuse because two records describe the same artifact using different path forms, and `zfa tdd doctor` must detect this registry drift and prescribe the documented recovery instead of reporting the stores as healthy.

## Functional Requirements

### Requirement 1

The system SHALL treat a recorded artifact path and an equivalent artifact path under the resolved project root as the same ownership path, regardless of whether either is absolute or project-relative.

#### Scenario: Mixed path forms in a registry

- **WHEN** a feature registry contains a relative path for one artifact and the same absolute path for another equivalent artifact
- **THEN** the TDD ownership preflight SHALL treat the equivalent paths as matching
- **AND** behavior regeneration SHALL reuse the registered artifacts instead of refusing with an ownership conflict

### Requirement 2

The system SHALL detect registry path-form drift in `zfa tdd doctor`.

#### Scenario: Doctor sees path-form-only drift

- **WHEN** two records in the same TDD registry describe the same canonical artifact path in different relative/absolute forms
- **THEN** doctor SHALL report a drift
- **AND** doctor SHALL prescribe a recovery action rather than reporting the feature healthy

### Requirement 3

The system SHALL keep committed TDD registry paths portable.

#### Scenario: Committed registry contains machine-specific paths

- **WHEN** a committed TDD registry records an artifact using a machine-specific absolute path
- **THEN** that record SHALL be normalized to the project-relative portable form

## Acceptance Criteria

- [ ] AC1: `zfa tdd gen` succeeds for a behavior whose prior registry path is relative while the generated path is absolute, when both resolve to the same artifact.
- [ ] AC2: `zfa tdd doctor` reports drift for path-form-only mismatches instead of `prescription: none`.
- [ ] AC3: Existing generated artifacts are unchanged by the ownership reconciliation.
- [ ] AC4: Committed registry records use portable project-relative artifact paths.

## Non-Goals

- No change to cross-feature ownership semantics.
- No broad migration of unrelated project files.
- No relaxed ownership acceptance for genuinely different paths.
