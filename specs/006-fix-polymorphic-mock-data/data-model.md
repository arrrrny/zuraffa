# Data Model: Fix Polymorphic Mock Data Generation

**Date**: 2026-05-24 | **Feature**: 006-fix-polymorphic-mock-data

## Overview

This feature modifies the mock data generation pipeline to correctly handle polymorphic entities. No new persistent data models are introduced. The changes affect how the tool processes entity source files at generation time.

## Key Entities (Processing Model)

### 1. Polymorphic Entity Detection

Represents the detection result for whether an entity is polymorphic and what its subtypes are.

| Field | Type | Description |
|-------|------|-------------|
| `entityName` | String | The entity being checked (e.g., `CategoryConfig`) |
| `isPolymorphic` | boolean | Whether the entity has detectable subtypes |
| `subtypes` | List\<String\> | Names of concrete subtype classes |

**Detection Sources** (checked in order):
1. `@Zorphy(explicitSubTypes: [...])` annotation (existing)
2. `sealed class` declarations with `extends` clauses (new)

**Rules**:
- Subtypes marked `abstract` or `sealed` are excluded — only leaf concrete classes
- Both detection sources are merged and deduplicated by subtype name
- Empty subtypes list = non-polymorphic, falls through to direct mock generation

### 2. Sealed Class Subtype

A concrete class within a sealed class hierarchy.

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | The class name (e.g., `PrimaryCategory`) |
| `baseType` | String | The sealed parent class name (e.g., `CategoryConfig`) |
| `isConcrete` | boolean | Always true for mock generation candidates |
| `fields` | Map\<String, String\> | Field name → type mapping from `analyzeEntity()` |

**Detection**: Regex scan for `class {Name} extends {BaseType}` within the same file, excluding lines that also match `abstract class` or `sealed class`.

### 3. Mock Data Instance

Generated Dart code expression representing an entity instance.

| Field | Type | Description |
|-------|------|-------------|
| `entityName` | String | The concrete type being instantiated |
| `expression` | String | Dart constructor call with values (e.g., `PrimaryCategory(id: 'id 1', ...)`) |
| `isPolymorphic` | boolean | Whether this instance uses a subtype rather than base type |

**Invariant**: For polymorphic entities, the `entityName` in generated expressions MUST always be a concrete subtype, never the sealed base class. This is the core invariant that was violated by the bug.

### 4. Entity Graph Node

Represents a node in the recursive entity type graph during mock generation.

| Field | Type | Description |
|-------|------|-------------|
| `entityName` | String | Name of this entity type |
| `fields` | Map\<String, String\> | Field name → type mapping |
| `subtypes` | List\<String\> | Polymorphic subtypes (if any) |
| `children` | List\<EntityGraphNode\> | Referenced entity types from fields |
| `processed` | boolean | Whether mock data has been generated for this node |

**Cycle Prevention**: The `processedEntities` set (already implemented in `mock_entity_graph_builder.dart`) prevents infinite recursion. This set is correctly maintained — the bug is in subtype detection, not recursion control.

## State Transitions

### `getPolymorphicSubtypes()` Return Paths

```
                    ┌─────────────────┐
                    │ Check @Zorphy    │
                    │ annotation       │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │ Found subtypes?  │
                    └───┬──────────┬───┘
                        │ YES      │ NO
                        ▼          ▼
                   Return      ┌─────────────────┐
                   subtypes    │ Check sealed     │
                               │ class pattern    │
                               └────────┬─────────┘
                                        │
                               ┌────────▼─────────┐
                               │ Found subtypes?  │
                               └───┬──────────┬───┘
                                   │ YES      │ NO
                                   ▼          ▼
                              Return       Return []
                              subtypes     (non-polymorphic)
```

### Mock Generation Decision

```
getPolymorphicSubtypes(entityName)
        │
        ├── subtypes.isNotEmpty ──► Generate mock data for EACH concrete subtype
        │                           (skip sealed/abstract base)
        │
        └── subtypes.isEmpty ────► Generate mock data for entityName directly
                                   (standard non-polymorphic path)
```

**Bug fix**: Before the fix, sealed classes always took the `subtypes.isEmpty` path and tried to instantiate the abstract base class. After the fix, sealed classes take the `subtypes.isNotEmpty` path and generate instances of concrete subtypes.
