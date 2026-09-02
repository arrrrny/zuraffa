# Feature Specification: Todo App

**Feature Branch**: `001-todo-app`

**Created**: 2026-09-02

**Status**: Draft

**Input**: Build a complete functional todo application (domain model,
statistics model, and domain logic) entirely through the `zfa tdd`
red-green-refactor loop. No hand-written domain or architecture code.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate the todo domain through the TDD loop (Priority: P1)

A developer starts from a bare `zfa setup` project and derives the whole
todo domain — the Todo entity, the TodoStats aggregate, and the domain
helpers (defaults, labels, limits, collectors) — from a single feature
specification. Every behavior starts red with an honest assertion
failure and flips green through generated implementation only, with the
full suite certified clean after each behavior.

**Why this priority**: The todo domain is the application. Without the
entity and its domain helpers there is no todo app; the presentation
layer is a thin consumer of these generated artifacts.

**Independent Test**: Can be fully tested by running
`zfa tdd run 001-todo-app` and confirming every behavior reaches DONE
with a green suite, then running `dart test` and `dart analyze` clean.

**Acceptance Scenarios**:

1. **Given** a fresh pure-Dart todo project, **When** the domain model for a todo item is generated, **Then** create entity Todo with id, title, description, isCompleted, priority, tags, createdAt, completedAt.
2. **Given** the todo domain model, **When** the aggregate statistics model is generated, **Then** create entity TodoStats with total, active, completed.
3. **Given** the todo application shell, **When** the list header is prepared for display, **Then** the status line formatter returns a non-empty string.

### Requirements *(mandatory)*

- **FR-001**: The default priority returns 1 when a todo is created without an explicit priority.
- **FR-002**: The maximum title length returns 120 when a title is validated.
- **FR-003**: The priority label formatter returns a non-empty string for every priority level.
- **FR-004**: The overdue tag collector returns a list of tag names.
- **FR-005**: The completion ratio compute returns 0 when the todo list is empty.
- **FR-006**: The persistence flag returns true when the journal is clean.
