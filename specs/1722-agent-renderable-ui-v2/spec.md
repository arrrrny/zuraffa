# Feature Specification: Agent-renderable UI v2 — a verifiable screen-description vocabulary

**Feature Branch**: `feat/issue-818`

**Created**: 2026-10-18

**Status**: Draft

**Input**: Issue [#818](https://github.com/arrrrny/zuraffa/issues/818) — "[VISION] Agent-renderable UI v2: a verifiable screen-description vocabulary".

## User Scenarios & Testing

### User Story 1 - Agent describes a screen as a vocabulary document (Priority: P1)

An AI agent emits a `ScreenDoc` (layout + semantic roles + labels + data bindings) instead of a raw widget tree. The framework renders real widgets from it and verifies a11y, hit-targets, and state coverage by construction.

**Acceptance Scenarios**:
1. Given a valid `ScreenDoc` for the notes app, when rendered, then a list-detail layout tree is produced.
2. Given the same doc, when verified, then verification passes.

### User Story 2 - Removing a semantic label fails verification naming the role (Priority: P1)

**Acceptance Scenarios**:
1. Given a `ScreenDoc` whose list node has its label removed, when verified, then verification fails with an error naming role "list".

## Requirements

### Functional Requirements
- **FR-001**: System MUST support a v2 vocabulary schema with containers, roles, bindings, and actions.
- **FR-002**: System MUST render three layouts: list-detail, form, dashboard.
- **FR-003**: System MUST verify labels present, hit-target sizes, and state-matrix coverage.
- **FR-004**: A notes-app vocabulary doc MUST render and pass verification.

## Success Criteria
- **SC-001**: Notes screen doc renders a list-detail layout.
- **SC-002**: Verification fails when a semantic label is removed, naming the role.

## Assumptions
- Pure-Dart v0 slice; pixel goldens deferred to host rendering layer.
