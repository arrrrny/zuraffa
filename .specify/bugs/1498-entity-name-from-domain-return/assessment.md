# Bug Assessment: domain contract resolves entityPipeline but never yields entityName (#1498)

- **Slug**: 1498-entity-name-from-domain-return
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1498
- **Verdict**: valid
- **Severity**: critical (16 of 21 unit behaviors in 001-todo-app are
  entityPipeline by declaration and ALL of them fall through to the
  hand seam — the entity→mock→wire engine is unreachable for the most
  natural spec shape)

## Report (verified against lib/src/plugins/tdd/services/)

A Domain-layer Layer Contract row (`TaskStore: create(String title) ->
Task`) resolves `surface = entityPipeline` — the CORRECT declared
surface — but the plan is thrown away, because the plan builder
requires `entityName`, which only a Key Entities row trace can supply.
The domain row's declared return type (`Task`) already carries the
entity, is already parsed into `RoutingDecision.signature`, and is
never read.

## Root cause

Two stale assumptions in the declared-intent ladder (feature 071):

1. `routing_resolver.dart` populates `entityName` exclusively from an
   `entityRow` (`if (entityRow != null) entityName = entityRow.name`).
   A domain/data row resolves `surface = entityPipeline` in the same
   switch, and its declared signature is resolved into
   `RoutingDecision.signature` (the issue #1259 remediation), but the
   signature's return type is never mined for the entity. The declared
   return type IS a declaration (issue #920: declaration outranks
   inference) — the resolver discards it.
2. `generation_planner.dart` `_declaredPlan` handles
   `GenerationSurface.entityPipeline` with
   `if (name == null) return null;` — a silent discard into the legacy
   keyword branches. For a `U<n>` behavior the legacy branch plans
   `tdd func`, whose contract-derived subject degrades the entity
   return to `Object?` with a vacuous guard — the #1489 symptom — and
   the run stops at the hand seam.

### What gets generated instead

The fallback reaches the prose-branch templater → `tdd func` →
`Object? subject_u16()` + vacuous guard → stopped at `U2:hand`.

### What the pipeline would have produced

`$ zfa make Task --preset=crud --dry-run` → 18 files (entity, mock,
wire, build — the full entityPipeline). The engine works; the
declared-intent route to it does not.

### Second door also closed (context, not this fix's surface)

The fallback entity detection (`_tracedEntityFor` in make_command.dart)
matches declared entity names against behavior PROSE with a
case-sensitive word-bounded regex. `Task` never matches
"…create a task by supplying…", so the FR traces to `TaskStore.create`,
not `Task`. With the resolver fixed, the declared ladder resolves the
entity before this prose fallback ever engages for declared rows.

## Impact

16 of 21 unit behaviors in `001-todo-app` trace to a domain row
returning `Task` / `List<Task>`. All 16 are `entityPipeline` by
declaration, all 16 fall through, all 16 land on the hand seam. Not
one exercises the entity→mock→wire engine.

## Remediation

1. **Mine the domain row's declared return type** (routing_resolver.dart):
   unwrap `Future<T>` / `List<T>` / `Set<T>` / `Iterable<T>` (repeatedly,
   nullability tolerated) from `signature.returnType`. When the result is
   a non-scalar declared entity name, set `entityName` and record the
   entity provenance. When the spec declares Key Entities rows and the
   mined name names none of them, the declaration is dangling — refuse
   (never guess). When the spec declares no Key Entities rows, the
   domain row's own return type is the only entity declaration there is
   (the "not from Key Entities only" hard requirement) and it is served.
   Renderable-scalar returns (`bool`, `String`, `int`, …) are not
   entity declarations: the declared contract IS a plain function and
   the func lane keeps serving it with the declared signature (pinned
   by issue #1310's U5/U6).
2. **Refuse, never silently discard** (generation_planner.dart): when
   the declared surface is `entityPipeline` but `entityName` is
   underivable and the declared return is not a renderable scalar, the
   plan builder returns the honest refusal (an unexpressible plan
   carrying `surface: entityPipeline (dropped: no entity name)` and a
   `--> fix:` hint) instead of `return null` into the legacy branches.
3. **Record the surface in routing provenance** (routing_resolver.dart):
   the surface provenance line names the computed surface
   (`surface: entityPipeline`), so plan's route line renders it.

State machine, gen, wire, and loop semantics untouched: the fix is
confined to `routing_resolver.dart` and `generation_planner.dart`.

## Related

#1489 (Object? degradation — the symptom), #1420, #1419, #1488/#1259
(vacuous-green), #1308 (hand seam), #920 (declaration outranks
inference), #951/spec 071 (declared-intent routing), #829, #1500
(wire accepts contract-derived subjects — the pipeline's wire step
already works), #1503 (the certify step's built-entity precondition).
