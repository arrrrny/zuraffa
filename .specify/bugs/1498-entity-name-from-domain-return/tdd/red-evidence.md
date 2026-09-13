# Red evidence: 1498-entity-name-from-domain-return

Recorded against the UNFIXED tree (branch
fix/1498-entity-name-from-domain-return @ b621f38b, before the
routing_resolver.dart / generation_planner.dart changes), via:

```bash
dart test test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart
```

Result: `00:00 +1 -8: Some tests failed.` — 8 of 9 behaviors RED, each
for the RIGHT reason; U-1498i (the scalar regression guard) green by
design.

| id | failure (right reason) |
| -- | ---------------------- |
| U-1498a | `Expected: 'Task' / Actual: <null>` — the #1498 gap: entityName never derived from the domain row's return type |
| U-1498b | plan steps lacked entity/mock/wire — the plan fell through to the legacy func lane |
| U-1498c | `Expected: contains 'surface: entityPipeline' / Actual: 'contract row: TaskStore'` — the computed surface was invisible in provenance |
| U-1498d | `Expected: 'Task' / Actual: <null>` for every unwrappable form (Future/List/Set/Iterable/nested/nullable) |
| U-1498e | `Expected: 'Task' / Actual: <null>` — DATA rows share the gap |
| U-1498f | `Expected: an object with length of <1> / Actual: []` — no entity provenance at all |
| U-1498g | `Expected: RoutingFailure / Actual: RoutingDecision` — a dangling entity return was silently decided |
| U-1498h | `Expected: false / Actual: true` — the plan builder discarded the surface and fell through to an expressible func plan |
| U-1498i | PASS (regression guard: the declared scalar contract keeps its lane — pinned preserved behavior) |
