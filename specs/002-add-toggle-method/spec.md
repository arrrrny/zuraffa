# Feature Specification: Add Toggle Method to Entity MethodList

**Feature Branch**: `002-add-toggle-method`  
**Created**: 2026-04-06  
**Status**: Draft  
**Input**: User description: "Add a toggle method to the entity methodList that allows toggling a boolean field on an entity"

## User Scenarios & Testing

### User Story 1 - Toggle a boolean field on an entity (Priority: P1)

As a developer using Zuraffa, I want to generate a `toggle` method for my entities so that I can flip boolean fields (like `isActive`, `isCompleted`, `enabled`) with a single API call.

**Why this priority**: This is a common CRUD pattern that eliminates the need for manual update logic when flipping boolean flags.

**Independent Test**: Can be fully tested by running `zfa make Entity --methods=get,update,toggle` and verifying the generated code includes toggle methods across all layers (repository, usecase, datasource, presenter, controller, state).

**Acceptance Scenarios**:
1. **Given** an entity with a boolean field, **When** running `zfa make Entity --methods=get,toggle`, **Then** a `toggle` method is generated in the repository interface, usecase, datasources (remote + local), presenter, controller, and state.
2. **Given** a boolean field name (e.g., `isCompleted`), **When** calling the generated `toggleEntity` method, **Then** the method accepts the entity ID, the field to toggle, and the new boolean value, and returns the updated entity.

---

### User Story 2 - Toggle method uses ToggleParams for type-safe parameters (Priority: P1)

As a developer, I want the toggle method to use the `ToggleParams` class so that the parameters (ID, field, value) are type-safe and follow the established parameter patterns in Zuraffa.

**Why this priority**: Consistency with existing parameter patterns (QueryParams, UpdateParams, DeleteParams) ensures predictable API and enables proper code generation.

**Independent Test**: Verify the generated toggle method signature uses `ToggleParams<IdType, Field<Entity, dynamic>>` and the ToggleParams class has `id`, `field`, and `value` fields.

**Acceptance Scenarios**:
1. **Given** an entity with `id: String`, **When** toggle method is generated, **Then** it uses `ToggleParams<String, Field<Entity, dynamic>>`.
2. **Given** the ToggleParams class, **When** inspecting its fields, **Then** it has `id`, `field`, and `value` (bool) fields.

---

### User Story 3 - Toggle parameter naming avoids collision with entity fields (Priority: P2)

As a developer, I want the toggle method's boolean value parameter to be named `toggleValue` instead of `value` to avoid collisions when the entity's ID field is named `value` (e.g., Barcode entity with `String get value` as its first field).

**Why this priority**: Without this fix, entities like Barcode would have a parameter name collision between the ID parameter (`String value`) and the toggle value parameter (`bool value`), causing compilation errors.

**Independent Test**: Generate code for an entity named `Barcode` with idField=`value` and verify the generated method uses `bool toggleValue` parameter and forwards it to `ToggleParams.value`.

**Acceptance Scenarios**:
1. **Given** an entity where the resolved ID field is `value`, **When** toggle method is generated, **Then** the boolean parameter is named `toggleValue`, not `value`.
2. **Given** the canonical entity with `id` field, **When** toggle method is generated, **Then** the boolean parameter is still named `toggleValue` (consistent behavior).

---

## Requirements

### Functional Requirements

- **FR-001**: System MUST generate a `toggle` method in the repository interface with signature `Future<Entity> toggle(ToggleParams<IdType, Field<Entity, dynamic>> params)`.
- **FR-002**: System MUST generate a `Toggle${Entity}UseCase` that extends `UseCase<Entity, ToggleParams<IdType, Field<Entity, dynamic>>>`.
- **FR-003**: System MUST generate a `toggle` method in the datasource interface, remote datasource (throwing UnimplementedError), and local datasource (using `copyWithField`).
- **FR-004**: System MUST generate a `toggleEntity` method in the presenter with parameters `(idField, field, toggleValue)`.
- **FR-005**: System MUST generate a `toggleEntity` method in the controller with parameters `(idField, field, toggleValue)`.
- **FR-006**: System MUST add `isToggling` boolean field to the generated state class.
- **FR-007**: System MUST use `toggleValue` as the parameter name for the boolean value (not `value`) to avoid collision with entity ID field named `value`.
- **FR-008**: System MUST forward `toggleValue` into `ToggleParams.value` field when constructing the params object.

### Key Entities

- **ToggleParams<I, F>**: Parameter class for toggle operations with generic ID type `I` and field type `F`. Contains `id: I`, `field: F`, `value: bool`.
- **Entity**: The domain entity for which toggle methods are generated.

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Running `zfa make Entity --methods=get,toggle` generates toggle methods across all layers without compilation errors.
- **SC-002**: The generated toggle method correctly toggles a boolean field in the local datasource implementation.
- **SC-003**: No parameter name collision occurs when entity's ID field is named `value` (verified by test in issue_302_toggle_param_collision_test.dart).
- **SC-004**: Generated code passes `dart analyze` and existing regression tests.

---

## Assumptions

- The `ToggleParams` class already exists in `lib/src/core/params/toggle_params.dart` and `toggle_params.zorphy.dart`.
- The entity already has boolean fields that can be toggled.
- The `zfa make` command accepts `toggle` as a valid method in the `--methods` flag.
- The feature is scoped to the `crud` preset and entity-based generation.

---

## Edge Cases

- What happens when the entity has no boolean fields? (The toggle method is still generated but operates on any field via `Field<Entity, dynamic>`).
- How does system handle the remote datasource toggle? (Throws `UnimplementedError` with message 'Implement remote toggle').
- What happens when the entity's ID field is named `value`? (Parameter renamed to `toggleValue` to avoid collision).
- What happens with pure-Dart targets? (VPC generation is skipped per Constitution VII, but usecase/repository/datasource layers still generate).