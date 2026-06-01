# Feature Specification: Fix Polymorphic Mock Data Generation

**Feature Branch**: `006-fix-polymorphic-mock-gen`  
**Created**: 2026-05-24  
**Status**: Draft  
**Input**: User description: "fix polymorphic mock data generation - zfa mock data CategoryConfig is failing when it has elements that are polymorphic, getting stuck"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate Mock Data for Sealed Class Entities (Priority: P1)

A developer defines a Dart entity using `sealed class` (e.g., `CategoryConfig` with subtypes like `PrimaryCategory`, `SecondaryCategory`) and runs `zfa mock data CategoryConfig` to generate mock data. The generator correctly detects the sealed class hierarchy, generates mock data for each concrete subtype, and produces valid, compilable Dart code without hanging.

**Why this priority**: This is the core regression — the generator completely fails for sealed class entities, previously working functionality is broken. Without this fix, developers cannot generate mock data for any sealed/polymorphic entity.

**Independent Test**: Create a minimal Dart entity file with a `sealed class` hierarchy (base class + 2 concrete subtypes), run `zfa mock data <EntityName>`, and verify that the generated mock data file compiles and produces valid subtype instances.

**Acceptance Scenarios**:

1. **Given** a Dart file containing a sealed class `CategoryConfig` with concrete subtypes `PrimaryCategory` and `SecondaryCategory`, **When** the developer runs `zfa mock data CategoryConfig --force`, **Then** the generator produces a valid mock data file within 10 seconds containing mock instances for each concrete subtype.
2. **Given** a sealed class where one subtype is abstract itself, **When** mock data is generated, **Then** only the leaf (concrete) subtypes receive mock data instances, and abstract intermediate types are skipped.
3. **Given** a sealed class with no concrete subtypes (all abstract), **When** mock data is generated, **Then** the generator exits with a clear warning message instead of hanging or producing invalid code.

---

### User Story 2 - Generate Mock Data for Zorphy-Polymorphic Entities Continues to Work (Priority: P1)

A developer uses the `@Zorphy(explicitSubTypes: [...])` annotation pattern for polymorphic entities. The mock data generator must continue to correctly detect polymorphic subtypes via the Zorphy annotation path and generate mock data for each, without regression from the new sealed class support.

**Why this priority**: The existing Zorphy-based polymorphic support must not break when sealed class support is added. This is the previously working path that must be preserved.

**Independent Test**: Create an entity using `@Zorphy(explicitSubTypes: [VariantA, VariantB])`, run `zfa mock data <EntityName>`, and verify the generated mock data includes instances for each explicit subtype.

**Acceptance Scenarios**:

1. **Given** an entity with `@Zorphy(explicitSubTypes: [TypeA, TypeB])`, **When** `zfa mock data <Entity>` runs, **Then** mock data is generated for both `TypeA` and `TypeB` subtypes.
2. **Given** an entity using both `sealed class` and `@Zorphy` patterns (mixed), **When** mock data is generated, **Then** subtypes from both detection paths are included without duplication.

---

### User Story 3 - Clear Error Messages for Unresolvable Entity Types (Priority: P2)

A developer provides an entity that cannot be resolved (missing file, typo, abstract class with no concrete subtypes found). Instead of hanging or silently producing invalid code, the generator provides a clear, actionable error message indicating what went wrong and exits.

**Why this priority**: While the primary fix targets sealed class support, error handling is needed to prevent the generator from appearing "stuck" in other failure scenarios.

**Independent Test**: Run `zfa mock data NonExistentEntity` and verify that the generator reports the entity cannot be found (instead of hanging), and exits with a non-zero code.

**Acceptance Scenarios**:

1. **Given** the entity file does not exist at the expected path, **When** `zfa mock data MissingEntity` runs, **Then** an error message states the entity file was not found, and the process exits within 5 seconds.
2. **Given** an entity that is abstract with no detectable concrete subtypes, **When** mock data is generated, **Then** a warning is displayed indicating that only leaf concrete types receive mock data, and no invalid abstract-class instantiation code is produced.
3. **Given** a nested entity type referenced by a field cannot be resolved, **When** mock data is generated, **Then** a warning identifies the specific unresolved type and the field, and generation continues with a placeholder for that field.

---

### Edge Cases

- What happens when a sealed class hierarchy spans multiple files (subtypes are in separate files)? The generator should detect subtypes within the same file at minimum; cross-file detection is out of scope for this fix.
- What happens when a sealed base class definition contains no concrete subtypes in the same file? The generator should warn and skip mock generation for that base type.
- What happens when a polymorphic type references itself recursively through its subtypes? The generator must not recurse infinitely — cycle detection should prevent this.
- What happens when an entity uses both `sealed class` from Dart and `@Zorphy` from the Zuraffa package? The generator should handle both detection paths and deduplicate subtypes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST detect Dart `sealed class` hierarchies as polymorphic entity types during mock data generation.
- **FR-002**: System MUST identify concrete subtypes (non-abstract, non-sealed leaf classes) within a sealed class hierarchy and generate mock data for each.
- **FR-003**: System MUST still generate mock data for entities using the existing `@Zorphy(explicitSubTypes: [...])` annotation pattern without regression.
- **FR-004**: System MUST skip abstract intermediate types within a sealed hierarchy and generate mock data only for leaf concrete subtypes.
- **FR-005**: System MUST produce valid, compilable Dart code in the generated mock data file for all supported polymorphic patterns.
- **FR-006**: System MUST NOT attempt to directly instantiate abstract classes or sealed base classes in generated mock data.
- **FR-007**: System MUST complete mock data generation for polymorphic entities within 10 seconds for entities with up to 10 subtypes.
- **FR-008**: System MUST exit with a clear error message when the specified entity file cannot be found, rather than hanging.
- **FR-009**: System MUST exit with a clear warning when a sealed class has no detectable concrete subtypes, rather than hanging or generating invalid instantiation code.

### Key Entities

- **Sealed Class Hierarchy**: A Dart sealed class acting as a base type with multiple subclass variants. The system must identify leaf concrete classes for mock generation.
- **Polymorphic Subtype**: A concrete class that extends or implements a sealed base class, representing one variant of the polymorphic type.
- **Mock Data Instance**: A generated Dart expression producing a populated instance of an entity, used for testing and UI previews.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running `zfa mock data <Entity>` for a sealed class with 2-10 concrete subtypes completes within 10 seconds and produces valid, compilable Dart code.
- **SC-002**: The generated mock data file for a sealed class entity passes static analysis with zero errors related to the mock data code.
- **SC-003**: Existing Zorphy-based polymorphic mock data generation continues to work identically — all existing tests for Zorphy mock generation pass without modification.
- **SC-004**: When given an unresolvable entity name, the generator exits with an appropriate error message in under 5 seconds (no hangs).
- **SC-005**: Developers can generate mock data for polymorphic entities and use the generated mock instances in widget tests without manual code fixes.

## Assumptions

- The entity file uses standard Dart conventions (sealed classes with subtypes defined in the same file, which is the typical Dart pattern for sealed hierarchies).
- The `zfa` CLI tool's existing infrastructure for mock data generation (MockBuilder, MockEntityGraphBuilder, MockValueBuilder) remains the foundation and needs extending, not rewriting.
- Cross-file sealed class subtype detection is out of scope for this fix — only same-file subtypes will be detected.
- The fix applies to the ZFA CLI tool specifically, not to runtime Zuraffa framework behavior.
- The `zfa mock data` command retains its existing CLI interface and flags (`--force`, `--output`, etc.).
