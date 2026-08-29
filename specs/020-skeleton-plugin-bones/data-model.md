# Data Model: Skeleton Plugin — Bare-Bones Feature Scaffold

Entities derived from the spec's "Key Entities" section, concretized for the
plugin implementation. All models are immutable value objects (plain Dart
classes with `final` fields); only the manifest is serialized (YAML).

## Bone

A self-contained scaffold for a single feature. Identified by feature slug.

| Field | Type | Notes |
|-------|------|-------|
| `featureSlug` | `String` | kebab-case, unique across `.zfa/bones/` |
| `featureName` | `String` | PascalCase display name |
| `rootDir` | `String` | `.zfa/bones/<feature-slug>/` |
| `manifest` | `BoneManifest` | see below |
| `entityStubs` | `List<EntityStub>` | ≥ 0; spec requires ≥ 1 for generation |
| `layers` | `List<LayerPlaceholder>` | fixed set: domain, data, presentation |

**Validation rules**
- `featureSlug` must match `^[a-z0-9]+(-[a-z0-9]+)*$`.
- `entityStubs` must be non-empty (edge case: incomplete spec → refuse output).
- Every import in generated stubs must resolve locally or via a declared
  dependency (FR-005).

## BoneManifest

Serialized to `bone.yaml` at the bone root.

| Field | Type | Notes |
|-------|------|-------|
| `feature` | `String` | feature slug |
| `version` | `int` | manifest schema version, starts at `1` |
| `generated_at` | `String` (ISO-8601) | emission timestamp |
| `spec_version` | `String` | `sha256:<hex>` of source spec.md (FR-008) |
| `entities` | `List<String>` | entity names declared by this bone |
| `dependencies` | `List<BoneDependency>` | see below; empty list when standalone |
| `layers` | `List<String>` | layer names with placeholders present |

**Validation rules**
- `spec_version` must match `^sha256:[0-9a-f]{64}$`.
- `dependencies` must not contain self-references.

## BoneDependency

One edge in the dependency graph.

| Field | Type | Notes |
|-------|------|-------|
| `bone` | `String` | slug of the depended-on bone |
| `entities` | `List<String>` | shared entity names justifying the edge |

**Validation rules**: `entities` non-empty — a dependency without a shared
entity is a modeling error (spec: dependencies derive FROM entity
cross-references).

## EntityStub

A placeholder Dart class for one entity inside the bone.

| Field | Type | Notes |
|-------|------|-------|
| `name` | `String` | PascalCase entity name |
| `fields` | `List<EntityField>` | name/type pairs from the entity declaration |
| `sourcePath` | `String` | bone-relative path, `lib/entities/<snake>.dart` |

**Validation rules**: `name` unique within the bone; conflicting definitions
of the same entity name across bones → generation refused (edge case 2).

## LayerPlaceholder

An empty-but-present layer directory with a README-style placeholder file so
the delegate agent sees the structure it must fill.

| Field | Type | Notes |
|-------|------|-------|
| `layer` | `String` | one of `domain`, `data`, `presentation` |
| `path` | `String` | bone-relative directory path |

## DependencyGraph

Acyclic directed graph over bones (spec: "Dependency Graph" entity).

| Field | Type | Notes |
|-------|------|-------|
| `nodes` | `Set<String>` | bone slugs |
| `edges` | `Map<String, List<String>>` | bone → bones it depends on |

**Operations / state transitions**
- `build(bones)` → graph; pure construction.
- `topologicalSort()` → `List<String>` build order, or `CycleException`
  naming the bones in the cycle (FR-004). The graph is valid iff the sort
  succeeds — there is no persistent "invalid" state; invalid graphs never
  produce output.

## Relationships

```text
Bone 1──1 BoneManifest
Bone 1──* EntityStub
Bone 1──* LayerPlaceholder
BoneManifest 1──* BoneDependency
DependencyGraph *──* Bone   (edges justified by ≥1 shared entity name)
```
