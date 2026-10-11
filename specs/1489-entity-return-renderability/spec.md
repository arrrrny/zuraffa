# Feature Spec: Entity-Returning Contracts Permanently Degrade to Object? [SPEC 1489]

**Feature ID:** 1489-entity-return-renderability
**Issue:** #1489
**Related:** #1486, #1308, #1259, #1007
**Status:** IMPLEMENTED

## Summary

Every entity-returning Layer Contract degrades to `Object?` in the generated
subject — permanently. `isRenderableDartType` (`unit_contract_shape.dart`) is
a pure function with no filesystem access: it answers "is this a scalar?" and
nothing else. An entity type never becomes renderable, even where phase-0 has
already created the entity before gen is spawned.

## Problem

`_renderableScalars = {void, Never, bool, String, int, double, num, dynamic,
Object}` — every entity type falls to `return false` unconditionally. Doc
comments (`unit_contract_shape.dart:16-21, 43-45`, `subject_writer.dart:211`)
imply the degradation lifts once the class exists. Nothing implements that
lift.

Consequences (observed on a real feature):

1. Every entity-returning contract is a permanent hand seam — `scalarOutcome`
   routes to the hand-step path for all entity returns. In the observed
   feature, this committed all 21 unit behaviors to hand-written assertions.
2. The generated stub cannot be implemented as written —
   `Object? subject_u1(String title)` vs contract
   `TaskStore.create(String title) -> Task`. The header instructs the author
   to "replace it with the declared type", doing work the framework had all
   information to do.

```dart
// Generated (wrong — entity exists at this point):
// A non-renderable declared type (an entity that does not exist yet)
Object? subject_u1(String title) => throw UnimplementedError('...');

// Expected (entity was created by phase-0):
Task subject_u1(String title) => throw UnimplementedError('...');
```

## Root Cause

`isRenderableDartType` consults only `_renderableScalars`. The entity
existence fact — which phase-0 guarantees before gen spawns, and which
`locateEntityFile` (`entity_lookup.dart`) already answers — never reaches the
predicate.

## Requirements

### FR-1 — Renderability gains entity-registry access

`isRenderableDartType` (or its caller, `UnitContractShape.of`) gains entity
registry access via `locateEntityFile`. When the entity exists on disk the
predicate returns true and the generated subject carries the declared type
(`Task subject_u1(...)`) — not `Object?`.

- FR-1.1: single entity (`Task`) renders verbatim when its file exists.
- FR-1.2: `List<Entity>` renders verbatim when the element entity exists.
- FR-1.3: `Entity?` renders verbatim when the entity exists.
- FR-1.4: `Map<K, Entity>` renders verbatim when the value entity exists
  (and the key type is renderable).

### FR-2 — Directly implementable stub

The generated subject includes the entity's import, so the stub compiles
against the declared type out of the box — the author implements the body,
never repairs the signature.

### FR-3 — scalarOutcome reflects corrected renderability

`scalarOutcome` reflects the corrected renderability: an existing
entity-return is a mechanically assertable outcome
(`expect(result, isA<Task>())`), so the paired test no longer routes
permanently to the hand-step seam. Missing entities keep the vacuous-guard
seam unchanged.

### FR-4 — Seam cost surfaced

`zfa tdd plan` surfaces the seam cost: "N of M unit behaviors will hand-step
because return is an entity" (in the test list, plus the plan's summary
output). The run driver announces the same forecast when a lane carries
entity-return seams.

### FR-5 — Backwards compatible degradation

Missing entities still degrade to `Object?`. The degradation is now
documented as CONDITIONAL: unconditional only for entities that do not exist
on disk (and for callers that pass no entity registry). Doc comments across
`unit_contract_shape.dart` and `subject_writer.dart` are corrected to state
exactly that.

## Hard Constraints

- Fix surface: `isRenderableDartType` / `unit_contract_shape.dart` /
  `subject_writer.dart` / `run_driver_core.dart` (plus the single call-site
  threading in `gen_command.dart` that passes the registry, and the paired
  test writer's import emission — the consumers of the shape data).
- Do NOT change the `BehaviorState` enum, state machine transitions, or the
  run driver loop.
- Must work for single entity, generic `List<Entity>`, nullable `Entity?`.
- Backwards compatible: missing entities still degrade to `Object?`; callers
  that pass no registry see today's behavior byte-for-byte.

## Measurable Success Criteria

1. `isRenderableDartType` (or caller) gains entity registry access via
   `locateEntityFile`. When entity exists on disk, predicate returns true.
   Generated subject carries declared type (`Task subject_u1(...)`) not
   `Object?`. **[SC-1]**
2. Generated subject includes entity's import — directly implementable
   stub. **[SC-2]**
3. `scalarOutcome` reflects corrected renderability — existing entity-returns
   not permanently routed to hand-step. **[SC-3]**
4. `zfa tdd plan` surfaces seam cost: "N of M unit behaviors will hand-step
   because return is an entity". **[SC-4]**
5. Missing entities still degrade to `Object?`. Doc comments corrected to
   state degradation is unconditional for non-existent entities. **[SC-5]**

## Out of Scope

- The contract lane's `ContractSubjectWriter` (its paired test stays BLOCKED,
  never RED — a different surface).
- `BehaviorState` transitions, the run driver loop, the make plan.
- Entity creation semantics (phase-0 owns them; unchanged).
