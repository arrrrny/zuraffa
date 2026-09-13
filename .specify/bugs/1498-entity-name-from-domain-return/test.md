# Test Plan: entityName from the domain row's declared return type (#1498)

Test file: `test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart`
(unit-level, pure — the resolver and the planner are pure by contract).

## RED behaviors (each must fail against the unfixed code for the RIGHT reason)

- **U-1498a** — a domain row `TaskStore: create(String title) -> Task`
  (Key Entities declares `Task`) resolves `entityName == 'Task'`
  (not null) with `surface == entityPipeline`. Fails today:
  `entityName` is null (only entity-kind rows set it).
- **U-1498b** — the plan builder turns that decision into the
  entityPipeline plan (4 steps: `entity create -n Task --build`,
  `mock create --name Task --certify`, `tdd wire … --entity Task`,
  `build`) — never a fall-through to `tdd func`. Fails today: the plan
  falls to the legacy func lane.
- **U-1498c** — the surface is recorded in routing provenance: the
  surface provenance line's detail carries `surface: entityPipeline`.
  Fails today: the detail names only the contract row.
- **U-1498d** — unwrapping matrix: `Future<Task>`, `List<Task>`,
  `Set<Task>`, `Iterable<Task>`, `Future<List<Task>>`, `List<Task>?`,
  `Task?` all derive `Task`. Fails today: nothing is mined.
- **U-1498e** — a `**Data**:` row (`CacheDao: fetch(String key) -> Task`)
  derives `Task` the same way (data rows share the entityPipeline
  surface). Fails today: nothing is mined.
- **U-1498f** — entity provenance is declared (source: declared,
  detail names the return type and the entity), never fallback.
  Fails today: no entity provenance exists for domain rows.
- **U-1498g** — the refusal: a domain row whose declared return is an
  entity-shaped type the spec's Key Entities rows do NOT declare
  (registry present, name dangling) refuses with
  `surface: entityPipeline (dropped: no entity name)` in the message
  and a `--> fix:` hint. Fails today: a silent RoutingDecision with
  null entityName.
- **U-1498h** — the plan builder refuses (honest unexpressible plan,
  `--> fix:` in the reason, `dropped: no entity name`) when it receives
  an entityPipeline decision with null entityName and no renderable
  scalar declared return — it must NOT fall through to `tdd func`
  steps. Fails today: falls through to the func plan.
- **U-1498i** — the declared scalar contract keeps its lane: a domain
  row `TodoRepository: create(String title) -> bool` resolves a
  RoutingDecision with a null entityName (not a refusal, not a mined
  `Bool` entity) and the planner still routes the legacy func lane
  (pins issue #1310's U5/U6 shape). Passes today — regression guard.

## GREEN criteria

- U-1498a…h pass; U-1498i passes.
- Chunked suite (all directly affected files) — NO NEW failures:
  routing_resolver_test, generation_planner_declared_test,
  bug_1503_mock_create_certify_pipeline_test, plan_traces_cell_1310,
  bug_1259_vacuous_green, bug_1500_wire_contract_subject,
  plan_unbound_traces_1319, bug_1320_declared_assertion_reachable,
  contract_kind_1007, plan_skin_contract_1004,
  contract_blocked_e2e_1007, bug_1141_ledger_wiring,
  spec_1142_adaptive_layout, bug_965_i18n_key_contracts,
  spec_parser_contract_files_1485, spec_parser_hardening_1196,
  function_contracts_parsing, bug_919_template_structures,
  ingest_command, dream_command.
- `dart analyze` on the changed files — no new warnings.
