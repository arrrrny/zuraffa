# Tasks: Dependency-Table Mocks (072)

**Feature**: specs/072-dependency-mocks | **Issue**: arrrrny/zuraffa#960
**Input**: design documents from `specs/072-dependency-mocks/` (plan, research, data-model, contracts)

## Phase 1: Setup

- [ ] T001 Declare feature scaffolding: create `specs/072-dependency-mocks/tdd/` via `zfa tdd plan 072-dependency-mocks` in the repo root worktree (test list derives from spec.md)

## Phase 2: Behaviors (TDD — red first, one behavior at a time)

_Classes: parser (dependency rows), mock capability (CLI + builder), routing/loop integration, realize parity._

- [ ] T002 **[behavior U1]** Dependency rows parse into contract declarations: a `service`-typed row becomes a `ContractRowDecl` with kind `service`, its contract cell parsed into `Signature`s, its priority cell parsed (`P1/P2/P3`/empty) — file: `lib/src/plugins/tdd/services/spec_parser.dart`
- [ ] T003 **[behavior U2]** A malformed contract cell keeps the row with raw signatures; the resolver refuses `malformedDeclaration` naming the row — files: `spec_parser.dart`, `routing_resolver.dart`
- [ ] T004 **[behavior U3]** Two dependency rows sharing a name produce a refusal naming both spec lines — file: `spec_parser.dart`
- [ ] T005 **[behavior U4]** `MockPriority` parses case-insensitively and sorts by `(tier, declarationIndex)`: P1 < P2 < P3 < none, stable within tier — files: `routing.dart`, `spec_parser.dart`
- [ ] T006 **[behavior U5]** `zfa mock dependency <Unknown>` refuses exit 2 with the add-the-row fix hint — files: `lib/src/plugins/mock/capabilities/dependency_mock_capability.dart` (new), `mock_plugin.dart`
- [ ] T007 **[behavior U6]** The capability generates the deterministic artifact package (interface = exactly the declared signatures; certified fake with scriptable slots + call recording; fixture lane) — files: `dependency_mock_capability.dart`, `builders/dependency_mock_builder.dart` (new)
- [ ] T008 **[behavior U7]** Regenerating an unchanged row is byte-identical; a changed row regenerates with the change surfaced — files: builder + capability
- [ ] T009 **[behavior U8]** Fake semantics: a scripted method returns the scripted value; an unscripted call raises a named error; recorded calls expose method, arguments, order (content-level assertion on the emitted fake)
- [ ] T010 **[behavior U9]** Routing: a behavior tracing to a declared service row resolves `surface = dependencyMake` with provenance naming `<Name> (<type>, priority <Pn>)`; a prose-only behavior is NOT routed — file: `routing_resolver.dart`
- [ ] T011 **[behavior U10]** A dependencyMake behavior whose mock artifacts are absent is refused (single AND batch lanes) with `--> fix: zfa mock dependency <Name>` — files: `generation_planner.dart`, `make_command.dart`, `verify_red_command.dart`
- [ ] T012 **[behavior U11]** The plan artifact's dependency section renders priority + order position per row — file: `plan_command.dart` (or its renderer)
- [ ] T013 **[behavior U12]** `zfa tdd realize --adapter <Name>` uses the declared contract as parity source: conforming adapter passes; drift refuses naming the member + row — file: `realize_command.dart`
- [ ] T014 **[behavior A1]** End-to-end: a login-shaped spec declaring FirebaseAuth (service, P1) + Hive (storage, P2) produces both mocks in priority order in one loop run, and a traced behavior runs green against the generated mock — files: capability + planner + make wiring

## Phase 3: Wiring & polish (non-behavior)

- [ ] T015 Register the `dependency` capability in `MockPlugin`'s capability list + CLI help text
- [ ] T016 Artifact registry records for dependency mocks (`dependency:<Name>` provenance, row line)
- [ ] T017 Docs: `docs/` + openwiki touchpoints for the new command; quickstart already in spec dir

## Phase 4: Verification

- [ ] T018 `dart analyze lib test` clean; scoped suites green; spec-whole verify (audit) run for the feature
