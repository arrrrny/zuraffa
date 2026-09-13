# Fix: entityName mined from the domain row's declared return type; plan builder refuses instead of discarding (#1498)

- **Slug**: 1498-entity-name-from-domain-return
- **Files**: `lib/src/plugins/tdd/services/routing_resolver.dart` and
  `lib/src/plugins/tdd/services/generation_planner.dart` (the ONLY files
  changed; the state machine, gen, wire, and loop semantics untouched)

## 1. `routing_resolver.dart` — mine the declared return type for the entity

Before: `entityName` was populated exclusively from a Key Entities row
trace, while the same switch already resolved `surface =
entityPipeline` for domain/data rows and the row's declared signature
into `RoutingDecision.signature` (the #1259 remediation). The declared
return type — a first-class declaration per issue #920 — was never
read.

After: when the computed surface is `entityPipeline`, `entityName` is
still null, and the surface row is DOMAIN/DATA, the resolver mines the
row's own declared return type:

```dart
final mined = signature == null
    ? null
    : _entityFromDeclaredReturn(signature.returnType);
```

`_entityFromDeclaredReturn` unwraps `Future` / `List` / `Set` /
`Iterable` repeatedly (nullability tolerated: `Future<List<Task>?>` →
`Task`) and returns the remaining identifier, or null when the declared
type names no entity — a renderable scalar (`void`, `Never`, `bool`,
`String`, `int`, `double`, `num`, `dynamic`, `Object`, `DateTime`,
`Duration`; the declared contract IS a plain function), a container
outside the unwrap list (`Map<…>`, `Result<…>`, `Stream<…>`), or a
non-identifier token.

Registry corroboration (never guess):

- The spec declares Key Entities rows and the mined name names one →
  served; entity provenance records the full declared signature
  (`declared return type of TaskStore.create(String title) -> Task
  (entity: Task)`).
- The spec declares Key Entities rows and the mined name names NONE →
  **`RoutingFailure` (danglingReference)**: `surface: entityPipeline
  (dropped: no entity name)`, naming the row, the offending return and
  the `--> fix:`.
- The spec declares no Key Entities rows → the domain row's own return
  type is the only entity declaration there is — served ("not from Key
  Entities only").

Surface provenance now names the computed surface
(`contract row: TaskStore — surface: entityPipeline`), so plan's route
line renders it and a dropped surface is never invisible.

## 2. `generation_planner.dart` — refuse, never silently discard

Before:

```dart
case GenerationSurface.entityPipeline:
  final name = result.entityName;
  if (name == null) return null; // undeclared aspect -> fallback
```

A computed surface the plan builder could not serve was thrown away
with `return null` — the legacy keyword branches then planned
`tdd func`, whose contract-derived subject degrades the entity return
to `Object?` behind a vacuous guard (the #1489 symptom) and dead-ends
at the hand seam.

After:

- `entityName != null` → `_entityPipelinePlan(summary, name)` — the
  same 4-step entity→mock→wire plan, extracted verbatim (the #1503
  built-entity precondition and certified-mock variant preserved).
- `entityName == null` and the declared return is a renderable scalar →
  `return null` — the labeled fallback keeps serving the one underivable
  shape that IS a plain function by declaration (the #1310 lineage:
  gen derives the declared scalar subject, the paired test asserts the
  typed outcome, make certifies).
- `entityName == null` and anything else → the honest refusal: an
  unexpressible plan carrying `surface: entityPipeline (dropped: no
  entity name)` and a `--> fix:` hint naming the declaration remedy.
  No steps — the legacy func lane cannot engage behind the declared
  surface.

## What this restores

A Domain-layer row `TaskStore: create(String title) -> Task` (the
001-todo-app shape; 16 of 21 unit behaviors) now plans the full
entity→mock→wire engine — `entity create -n Task --build` → `mock
create --name Task --certify` → `tdd wire <id> --entity Task` →
`build` — instead of falling through to `tdd func`'s `Object?`
subject + vacuous guard.

## Scope notes (hard-constraint compliance)

- Only `routing_resolver.dart` (derivation + provenance) and
  `generation_planner.dart` (plan builder) changed.
- The state machine, gen, wire and loop semantics are untouched:
  `tdd wire`'s contract-subject binding (#1500), the mock certify
  step (#1503) and the make composition fallback all behave exactly
  as before on their own inputs.
- `_tracedEntityFor`'s prose regex (make_command.dart) is left
  as-is by design: the declared ladder now resolves the entity for
  every declared domain/data row BEFORE the prose fallback engages,
  which closes the issue's second door for declared behaviors without
  regressing the #829 labeled-fallback contract its tests pin
  (criterion-only traces whose description prose names the entity).
- The plan-time lane report (#1498 expected item 5) requires a
  make/plan-command run tally outside this fix's constrained file
  surface; the per-route provenance line (surface recorded) delivers
  the same information per behavior.
