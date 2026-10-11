# Feature Specification: `zfa make engine` One-Shot Preset

**Feature Branch**: `077-make-engine-preset`

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "Re-implement and validate the `zfa make engine <Entity>` one-shot preset (GitHub issue #1109, parent #1013 ENGINE-PIPELINE), with idempotent DI registrations, an engine receipt, and a built-in `zfa engine check` gate, validated against the 005-login-engine sandbox. Supersedes #1080 (closed without merge)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate a complete engine slice with one command (Priority: P1)

A developer working on a Zuraffa project wants the full vertical architecture for one entity — use case, service, repository, datasource, certified mock, DI registration, and test scaffold — without invoking seven separate commands or knowing the internal chain. They run one command naming the entity and optionally listing methods, and every layer for that entity exists, compiles, and is wired together.

**Why this priority**: The one-shot engine generation is the entire point of the feature; without it there is no value delivered.

**Independent Test**: In a fresh project, run the engine command for an entity and verify that all generated layers exist, the project's tests pass, and a receipt listing every generated method is produced.

**Acceptance Scenarios**:

1. **Given** a fresh project with an existing entity, **When** the developer runs the engine command for that entity with a method list, **Then** all layers of the engine slice for each requested method are generated and the command exits successfully.
2. **Given** a generated engine slice, **When** the developer runs the project's test suite, **Then** the engine tree's tests pass alongside the rest of the suite.
3. **Given** a completed engine generation, **When** the developer inspects the generation artifacts, **Then** a machine-readable engine receipt exists listing every generated method with certification status and the source files involved.

---

### User Story 2 - Regenerate and re-register without breakage (Priority: P2)

A developer re-runs the engine command (for example, after adding a method or regenerating during iteration). Because dependency registrations are idempotent and prior outputs are handled deterministically, the second run does not crash with "already registered" errors, does not duplicate registrations, and leaves the project in a working state.

**Why this priority**: Non-idempotent regeneration was the defect that invalidated the previous attempt; without it the command cannot be used more than once, which blocks the iterate-and-extend workflow.

**Independent Test**: Run the engine command twice for the same entity (including invoking dependency setup twice in test code) and verify no registration errors occur and the project still works.

**Acceptance Scenarios**:

1. **Given** an entity whose engine slice was already generated, **When** the engine command runs again for the same entity, **Then** it completes without an "already registered" failure.
2. **Given** generated dependency setup code, **When** the setup function is invoked twice in the same session, **Then** no exception is thrown (registration is unregister-first).
3. **Given** generated dependency setup code, **When** the developer calls the companion reset function and then setup again, **Then** the reset clears registrations cleanly and setup succeeds.

---

### User Story 3 - Verify an engine slice passes its certification gate (Priority: P2)

A developer (or a CI gate) wants a single command that proves a generated engine slice is sound: it analyzes cleanly, every method in the receipt is mock-certified, and the engine tree stays free of UI-framework imports. The check command reports pass or fail with actionable detail.

**Why this priority**: The check turns generation from "files were written" into "the slice is verifiably correct," and it is the input other pipeline work depends on.

**Independent Test**: Run the check command against a generated engine slice and verify it exits successfully on a healthy slice and fails with a clear reason when a condition is violated.

**Acceptance Scenarios**:

1. **Given** a healthy engine slice, **When** the check command runs, **Then** it exits 0.
2. **Given** an engine tree containing a UI-framework import, **When** the check command runs, **Then** it exits non-zero and names the offending file.
3. **Given** a receipt containing a method that is not mock-certified, **When** the check command runs, **Then** it exits non-zero and names the uncertified method.
4. **Given** an engine slice whose code does not analyze cleanly, **When** the check command runs, **Then** it exits non-zero and surfaces the analysis findings.

---

### User Story 4 - Trust-tier generator test coverage (Priority: P3)

A maintainer of the generator wants confidence that each generated artifact type (use case, service, repository, datasource, mock provider) is correct, backed by per-generator behavioral test suites covering structure and compilation.

**Why this priority**: Quality infrastructure; it protects every future change but delivers no direct user-facing capability on its own.

**Independent Test**: Run each generator's test suite and verify it contains at least two behavioral tests (structural and compile-level) and that they pass.

**Acceptance Scenarios**:

1. **Given** the generator test tree, **When** the suites for the five artifact types run, **Then** each suite contains at least two behavioral tests and all pass.
2. **Given** a change that breaks one generator's output, **When** that generator's suite runs, **Then** at least one test fails, naming the broken artifact.

---

### Edge Cases

- What happens when the entity does not exist in the project? The command must fail with a clear error before generating anything, rather than producing a half-generated slice.
- What happens when only a subset of methods is requested? Only those methods are generated end-to-end and listed in the receipt; other methods of the entity are untouched.
- What happens when the receipt is missing at check time? The check fails with a message indicating generation must be (re)run.
- What happens when the command is run on an entity that already has a receipt? The receipt is updated to reflect the latest run, not appended to with duplicates.
- What happens when the engine command is interrupted mid-generation? A subsequent run must be able to complete the slice without manual cleanup (generation is re-runnable).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a single command that generates the full engine slice (use case, service, repository, datasource, mock, DI registration, test scaffold) for a named entity in one invocation.
- **FR-002**: The command MUST accept a comma-separated method list (get, getList, create, update, delete) and generate only the requested methods.
- **FR-003**: The command MUST accept flags to enable cache support and sync support in the generated slice, and to force datasource generation.
- **FR-004**: All code in the generated engine tree MUST be free of UI-framework imports; the engine generation MUST enforce this boundary as a built-in check, not an ad-hoc external test.
- **FR-005**: Generated dependency registration code MUST be idempotent: it MUST unregister an existing registration before registering, so repeated setup does not throw.
- **FR-006**: Generated DI code MUST include a reset function alongside the setup function so tests can clear and re-establish registrations.
- **FR-007**: The system MUST write a machine-readable engine receipt after generation, containing the entity name, every generated method with its certification status and mock class, and the list of generated source files.
- **FR-008**: Every generated method's mock MUST be certified before the receipt records it as certified; any uncertified method is visible in the receipt.
- **FR-009**: The system MUST provide a check command that validates an entity's engine slice by (a) running static analysis on the engine tree, (b) verifying the engine receipt exists and contains no uncertified method, and (c) verifying zero UI-framework imports in the engine tree; it exits non-zero if any condition fails.
- **FR-010**: The check command MUST report actionable failures (which file violated the import boundary, which method is uncertified, which analysis findings exist).
- **FR-011**: Each of the five generated artifact types (use case, service, repository, datasource, mock provider) MUST have a dedicated behavioral test suite with at least two tests: one structural and one compile-level.
- **FR-012**: The command chain MUST be re-runnable: running generation again for the same entity either updates or safely replaces prior output without corrupting the project.

### Key Entities *(include if feature involves data)*

- **Engine Slice**: The full vertical set of generated artifacts for one entity (use case, service, repository, datasource, mock, DI, tests); the unit generated by the one-shot command and validated by the check command.
- **Engine Receipt**: A per-entity machine-readable record of what was generated: entity, per-method certification status and mock class, and generated source files; consumed by downstream certification gates.
- **Entity**: The domain object (e.g., User) for which the engine slice is generated; must already exist in the project before engine generation.

## Lanes *(include when the feature splits engine vs. skin)*

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1-A3, U1-U12]
    flutter_allowed: false
  - lane: SKIN
    behaviors: []
    flutter_allowed: true
  - lane: BOTH
    behaviors: []
    flutter_allowed: conditionally
```

This feature is pure generator/CLI work with no presentation surface; the entire behavior set lives in the CORE (pure Dart) lane, and the no-UI-framework-imports boundary (FR-004) is itself a CORE-guarded invariant.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a fresh project, generating an engine slice for an entity takes one command and the resulting slice's tests pass on the first run without manual fixes.
- **SC-002**: Running the check command on a healthy, freshly generated slice exits successfully 100% of the time.
- **SC-003**: Running generation twice for the same entity produces zero "already registered" errors and zero duplicated artifacts.
- **SC-004**: The engine tree contains zero UI-framework imports, verified by the built-in boundary check, for every generated slice.
- **SC-005**: The receipt lists every requested method with certified mock status; no method is left uncertified after a successful generation.
- **SC-006**: Each of the five generator test suites runs green and contains at least two behavioral tests.

## Assumptions

- The entity must already exist (created via the standard entity workflow) before the engine command runs; entity creation remains separate.
- The default method set, when none is specified, follows the standard CRUD set (get, getList, create, update, delete).
- The receipt is written under the feature's test-development directory, consistent with where existing pipeline receipts live, so downstream certification gates can locate it by convention.
- Validation happens against the existing login-engine sandbox project used by the parent pipeline effort; the sandbox is expected to generate a working slice end-to-end.
- The previous attempt's approach is superseded; no code from it is assumed to survive.
- Sync and cache flags map onto the existing cache/sync capabilities already present in the generator; this feature wires them into the engine preset rather than defining new capability semantics.
