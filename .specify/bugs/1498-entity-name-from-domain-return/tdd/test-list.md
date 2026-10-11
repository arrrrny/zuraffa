# Test List: 1498-entity-name-from-domain-return

feature: 1498-entity-name-from-domain-return
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md

## Inner loop: unit behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U-1498a | a domain row create(String title) -> Task resolves entityName "Task" (not null) with the entityPipeline surface | FR-1498 | unit | DONE | test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart |
| U-1498b | the plan builder serves the declared entityPipeline plan — entity create → mock create (certify) → tdd wire → build, never the tdd func fall-through | FR-1498 | unit | DONE | test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart |
| U-1498c | the surface is recorded in routing provenance (surface: entityPipeline in the route line) | FR-1498 | unit | DONE | test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart |
| U-1498d | the unwrap matrix — Task / Future<Task> / List<Task> / Set<Task> / Iterable<Task> / Future<List<Task>> / List<Task>? / Task? / Future<List<Task>?> all mine Task | FR-1498 | unit | DONE | test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart |
| U-1498e | a DATA row mines the entity the same way (data rows share the entityPipeline surface) | FR-1498 | unit | DONE | test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart |
| U-1498f | the mined entity is DECLARED provenance naming the full declared signature — never fallback, never prose | FR-1498 | unit | DONE | test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart |
| U-1498g | an entity-shaped return the spec's Key Entities do not declare is a refusal — surface: entityPipeline (dropped: no entity name) — never a silent decision | FR-1498 | unit | DONE | test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart |
| U-1498h | the plan builder refuses (never falls through) when entityPipeline is computed but entityName is underivable and the declared return is not a renderable scalar | FR-1498 | unit | DONE | test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart |
| U-1498i | a declared scalar contract keeps its lane — no entity mined, no refusal, the legacy func plan still serves it (issue #1310 U5/U6 lineage regression guard) | FR-1498 | unit | DONE | test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart |

## Notes

- RED-first evidence: U-1498a…h failed against the unfixed tree for the
  RIGHT reasons (entityName null / plan fell through to func / no
  surface provenance / RoutingDecision instead of refusal / refusal plan
  expressible). U-1498i is the regression guard and was green from the
  start by design (it pins preserved behavior).
- See red-evidence.md and verification.md.
