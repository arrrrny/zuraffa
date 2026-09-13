# Issue: domain-layer contract resolves entityPipeline but never yields entityName (#1498)

## Summary

**Issue #1498 (CRITICAL):** Domain-layer Layer Contract row resolves
`surface = entityPipeline` — then the plan is thrown away because the
plan builder requires `entityName`, which only a Key Entities row can
supply. The domain row's declared return type (`Task`) contains the
entity, is already parsed into `RoutingDecision.signature`, and is
never read.

## The routing gap

`routing_resolver.dart` — domain row resolves the surface correctly:

```dart
case ContractRowKind.domain:
case ContractRowKind.data:
case ContractRowKind.entity:
  surface = GenerationSurface.entityPipeline;   // ← reached, correctly
```

… but `entityName` is only set from an entity-kind row:

```dart
if (entityRow != null) {
  entityName = entityRow.name;  // domain row never sets this
}
```

`generation_planner.dart` `_declaredPlan` — the plan builder discards:

```dart
case GenerationSurface.entityPipeline:
  final name = result.entityName;
  if (name == null) return null; // ← falls through to legacy branches
```

## What gets generated instead

The fallback reaches the prose-branch templater → `tdd func` →
`Object? subject_u16()` + vacuous guard → stopped at `U2:hand`.

## What the pipeline would have produced

```bash
$ zfa make Task --preset=crud --dry-run
✅ Created: 18 files (entity, mock, wire, build — the full entityPipeline)
```

The engine works. The declared-intent route to it does not.

## Second door also closed

The fallback entity detection (`_tracedEntityFor` in make_command.dart)
matches entity name against behavior **prose** with a case-sensitive
word-bounded regex. `Task` never matches "…create a task by
supplying…". The FR traces to `TaskStore.create`, not `Task`.

## Impact

**16 of 21 unit behaviors** in `001-todo-app` trace to a domain row
returning `Task` / `List<Task>`. All 16 are `entityPipeline` by
declaration, all 16 fall through, all 16 land on the hand seam. Not one
exercises the entity→mock→wire engine.

## Expected

1. **Mine the domain row's return type for the entity.** Unwrap
   `Future<T>` / `List<T>` / `Set<T>` / `Iterable<T>` from
   `signature.returnType`. When the result is a declared entity, set
   `entityName`.
2. **If still underivable, refuse** — a computed surface the plan
   builder cannot serve should be a `RoutingFailure` naming the row and
   the fix, not a `return null` into a legacy branch.
3. **Record the surface in routing provenance.** `surface:
   entityPipeline` in the route line; `surface: entityPipeline (dropped:
   no entity name)` in failure.
4. **Replace `_tracedEntityFor`'s prose regex** with the
   trace/declaration lookup.
5. **Plan-time report:** `unit lane: N entityPipeline, M plainFunction,
   K unexpressible`.

## Hard constraints

- Fix ONLY the `entityName` derivation in `routing_resolver.dart` and
  the plan builder in `generation_planner.dart`. Do NOT change the state
  machine, gen, wire, or loop semantics.
- Must derive `entityName` from the domain row's own return type — not
  from prose, not from Key Entities only.
- Must refuse (not silently fall through) when `entityPipeline` is
  computed but `entityName` cannot be derived.
- Must pass `dart analyze` with no new warnings.

Related: #1489, #1420, #1419, #1488/#1259, #1308, #920, #951/spec 071,
#829.
