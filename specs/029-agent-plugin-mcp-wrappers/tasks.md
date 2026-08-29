# Tasks: AgentPlugin — McpTool Wrappers for UseCases

**Input**: Design documents from `specs/029-agent-plugin-mcp-wrappers/` (spec.md, plan.md)

**Tests**: All implementation tasks include paired test tasks (test-first). Tests under `test/agent/plugin/`.

**Organization**: MVP-first. MVP tasks prefixed `[MVP]`.

## Path Conventions

- Source: `lib/src/agent/plugin/...`
- Output target (generated): `lib/src/agent/tools/...`
- Tests: `test/agent/plugin/...`
- Fixtures: `test/agent/plugin/_fixtures/`
- Public exports via `lib/zuraffa.dart` (new barrel `lib/src/agent/plugin/agent_plugin.dart`).

---

## Phase 1: Foundation (FR-001)

- [ ] T001 [MVP] Create `lib/src/agent/plugin/agent_plugin.dart` — empty `AgentPlugin` shell (id='agent', name='Agent Plugin', version='1.0.0') extending `FileGeneratorPlugin`. `generateWithContext` returns `[]`.
- [ ] T002 [MVP] Register `AgentPlugin(outputDir: outputDir, options: options)` at the end of `PluginLoader._plugins()` (lib/src/cli/plugin_loader.dart) with a `// 029-agent-plugin-mcp-wrappers` comment.
- [ ] T003 [MVP] Add `'agent': false,` to `ZfaConfig._builtinPluginDefaults` (lib/src/config/zfa_config.dart) with a comment.
- [ ] T004 [MVP] Add `if (_isTrue(options['agent'])) selection.add('agent');` to `PlanResolver._selectionFromOptions` (lib/src/core/planning/plan_resolver.dart) with a comment.
- [ ] T005 [MVP] Test: `zfa make Foo --agent` surfaces `AgentPlugin` in `plan.activePlugins` (smoke test asserting the plugin is active when the flag is parsed).

## Phase 2: UseCase Introspection (FR-004)

- [ ] T006 [MVP] Define `class UseCaseMetadata { final String className; final String paramsType; final List<ParamField> paramsFields; final String returnType; final bool isAgentInternal; final String verb; }` and `class ParamField { final String name; final String type; final bool isRequired; final Object? defaultValue; }` in `lib/src/agent/plugin/usecase_introspector.dart`.
- [ ] T007 [MVP] Implement `UseCaseIntrospector.introspect(String entityName, String projectRoot) → Future<List<UseCaseMetadata>>` that walks `lib/src/domain/usecases/{domain}/` for `*_{entitySnake}_usecase.dart` files, parses each with `analyzer`'s `parseFile`, extracts the `class X extends UseCase<ReturnT, ParamsT>` declaration, walks `ParamsT`'s fields, and detects `@AgentInternal()` annotation.
- [ ] T008 [MVP] Test: introspect a fixture entity with `Get`, `Create`, `Update`, `Delete` use cases → assert 4 metadata records with correct class names, param types, return types, verbs (`get`/`create`/`update`/`delete`).
- [ ] T009 [MVP] Test: introspect an entity with NO use cases → returns empty list and logs an informational message (NOT an error). Covers the Edge Case "Entity with no UseCases".

## Phase 3: Schema Derivation (FR-006, SC-002)

- [ ] T010 [MVP] Define `class SchemaDeriver` in `lib/src/agent/plugin/schema_deriver.dart` with `Map<String, dynamic> deriveFromTypeRef(String typeRef, {Set<String>? visiting})`.
- [ ] T011 [MVP] Implement primitive mappings: `String`→`{"type":"string"}`, `int`→`{"type":"integer"}`, `double`/`num`→`{"type":"number"}`, `bool`→`{"type":"boolean"}`.
- [ ] T012 [MVP] Implement `DateTime` → `{"type":"string","format":"date-time"}`.
- [ ] T013 [MVP] Implement `List<T>` → `{"type":"array","items":{...T...}}` and `Map<String,V>` → `{"type":"object","additionalProperties":{...V...}}`.
- [ ] T014 [MVP] Implement nullable `T?` → schema for `T` with `"nullable": true` added.
- [ ] T015 [MVP] Implement enum mapping (resolve enum value names from AST) → `{"type":"string","enum":[...]}`.
- [ ] T016 [MVP] Implement nested Zorphy entity → inline its fields as nested object schema (recursive descent; cycle guard via `_visiting` set returning `{"$ref":"#/definitions/$entityName"}`).
- [ ] T017 [MVP] Implement `SignalResult<T>` unwrapping → schema for `T`.
- [ ] T018 [MVP] Implement unresolvable / generic-with-unresolved-typearg → `{"type":"object","description":"Unresolvable type X"}` + log warning.
- [ ] T019 [MVP] Test: schema matrix test covering every supported type, asserting exact JSON Schema shape (SC-002).

## Phase 4: Tool Wrapper Emission (FR-005, SC-001)

- [ ] T020 [MVP] Define `class ToolWrapperEmitter` in `lib/src/agent/plugin/tool_wrapper_emitter.dart` with `Library emit(UseCaseMetadata, String entityName, String namespace)`.
- [ ] T021 [MVP] Generate namespaced tool name: `{namespace}.{entitySnake}.{verb}` (verb derived from UseCase class name prefix — e.g. `CreateListingUseCase` → `create`). Configure namespace via `agent` config or `--agent-namespace=foo`; default `app`.
- [ ] T022 [MVP] Emit `class {Verb}{Entity}Tool extends McpTool` with `name`, `description`, `inputSchema` (from `SchemaDeriver` on Params fields), `outputSchema` (from `SchemaDeriver` on return type), and `call(arguments)`. The `call` body: build `Params` from the args map via `Map<String, dynamic>` cast, resolve the UseCase via `getIt<{UseCaseClassName}>()`, invoke, wrap result into `McpToolResult(text: jsonEncode(result), data: {'result': result})`. Wrap in `try/catch` returning `McpToolResult(isError: true, text: e.toString())` on failure.
- [ ] T023 [MVP] Test: generate a tool wrapper for a fixture UseCase; assert the emitted source parses cleanly with `analyzer.parseFile` and `dart analyze` is clean (SC-001 codegen leg).
- [ ] T024 [MVP] Test: instantiate the emitted wrapper, register the fixture UseCase in a fake `getIt`, invoke `call` with sample args, assert a valid `McpToolResult` with expected `data['result']` (SC-001 runtime leg).

## Phase 5: Manifest Barrel (FR-007)

- [ ] T025 [MVP] Define `class ManifestEmitter` in `lib/src/agent/plugin/manifest_emitter.dart` with `Library emit(List<ToolManifestEntry> entries)`.
- [ ] T026 [MVP] Define `class ToolManifestEntry { final String name; final String entity; final String riskTier; }` in `lib/src/agent/plugin/manifest_entry.dart`. `riskTier` is `'safe'` or `'admin'`.
- [ ] T027 [MVP] Default risk tier = `safe`; if `UseCaseMetadata.isAgentInternal == true` → `admin`.
- [ ] T028 [MVP] Emit `const List<ToolManifestEntry> agentTools = [...]` plus a grouped `const Map<String, List<ToolManifestEntry>> agentToolsByEntity = {...}`.
- [ ] T029 [MVP] Test: generate the manifest for a 2-entity fixture (Listing with 4 verbs + Order with 3 verbs) → assert the manifest lists all 7 tools, groups by entity, and assigns correct risk tiers.

## Phase 6: Idempotent Merge (FR-008, FR-009, SC-003)

- [ ] T030 [MVP] Define `class GeneratedMarkerMerger` in `lib/src/agent/plugin/generated_marker_merger.dart` with `String mergeOrFresh({String? existing, required String newGeneratedContent, required String filePath})`.
- [ ] T031 [MVP] If `existing` is null → return `newGeneratedContent` wrapped with `// GENERATED - DO NOT EDIT ... // END GENERATED` markers.
- [ ] T032 [MVP] If `existing` does NOT contain `// GENERATED - DO NOT EDIT` markers AND has non-whitespace content → throw `ManualFileConflictException(filePath)`.
- [ ] T033 [MVP] If `existing` DOES contain markers → replace ONLY the block between (and including) the markers; preserve everything above and below verbatim.
- [ ] T034 [MVP] Test: generate, record SHA256 of each generated file, regenerate → assert all SHAs identical (SC-003 idempotency leg).
- [ ] T035 [MVP] Test: inject `// Hello from a developer` above the GENERATED block in a generated tool file; regenerate → assert the manual line is preserved AND the generated block is refreshed (SC-003 manual-extension leg).
- [ ] T036 [MVP] Test: hand-write a tool file with no markers in `lib/src/agent/tools/`; run generation → assert `ManualFileConflictException` is thrown naming the path (FR-009).

## Phase 7: Collision Detection (FR-009)

- [ ] T037 [MVP] Define `class ToolNamespace` in `lib/src/agent/plugin/tool_namespace.dart` with `static String canonicalOf(String namespace, String entity, String verb)` and `class CollisionDetector { void register(String canonical, String entity); }` that throws `ToolNameConflictException(canonical, existingEntity, incomingEntity)` on the first duplicate.
- [ ] T038 [MVP] Wire the `CollisionDetector` into `AgentPlugin.generateWithContext` so collisions are detected BEFORE any file is written (atomic).
- [ ] T039 [MVP] Test: fixture with two entities both producing `app.item.create` → generation fails with `ToolNameConflictException`.
- [ ] T040 [MVP] Test: same verb across DIFFERENT entities (e.g. `app.listing.create` and `app.order.create`) → NO collision (canonical names differ).

## Phase 8: Stale Tool Cleanup (FR-008)

- [ ] T041 [MVP] Implement `_sweepStaleTools` in `AgentPlugin.generateWithContext` after successful emission: scan `lib/src/agent/tools/` for files containing `// GENERATED` markers whose canonical tool name (parsed from the file's emitted `name` getter) is NOT in the newly emitted set → delete via `FileUtils.deleteFile`. NEVER delete files without markers.
- [ ] T042 [MVP] Test: generate 4 tool files, remove one UseCase, regenerate → assert the orphaned tool file is deleted and the manifest no longer references it.

## Phase 9: Opt-in Config Precedence (FR-003, SC-004)

- [ ] T043 [MVP] Test: 4-combination matrix —
  - flag on (`--agent`), config on (`agentByDefault: true`) → generates
  - flag on (`--agent`), config off (`agentByDefault: false`) → generates (flag wins)
  - flag off (`--no-agent`), config on (`agentByDefault: true`) → does NOT generate (flag wins)
  - flag off (no flag), config off → does NOT generate
- [ ] T044 [MVP] Test: `zfa make Foo --preset=crud` WITHOUT `--agent` and WITHOUT `agent: true` config → no tool files generated and no `lib/src/agent/tools/` directory created (User Story 4 Acceptance Scenario 1).

## Phase 10: Code Quality (FR-010)

- [ ] T045 [MVP] Run `dart analyze` on the new `lib/src/agent/plugin/` and `test/agent/plugin/` source; assert zero warnings.
- [ ] T046 [MVP] Run `dart analyze` on a freshly-generated fixture output (`lib/src/agent/tools/`); assert zero warnings.
- [ ] T047 [MVP] Run `dart format --set-exit-if-changed lib/src/agent/plugin/ test/agent/plugin/`; assert no diff.
- [ ] T048 [MVP] Run `dart test test/agent/plugin/`; assert all tests GREEN.

## Phase 11: SDD Artifacts & Polish

- [ ] T049 [MVP] Write `tdd/test-list.md` (FR→test name mapping table) — done as part of TDD plan step.
- [ ] T050 [MVP] Capture `tdd/red-evidence.md` from the first `dart test test/agent/plugin/` run BEFORE implementation.
- [ ] T051 [MVP] Write `tdd/verification.md` after all tests are GREEN, including the test-smell rubric and mutation results (manual review with concrete mutants per file).
- [ ] T052 [MVP] Ensure no `// TODO`, no `print()` debug, no commented-out code in the final implementation.
- [ ] T053 [MVP] Ensure all public APIs in `lib/src/agent/plugin/` have doc comments.

## Phase 12: Integration & Commit

- [ ] T054 [MVP] Verify full `dart analyze` (whole project) is still clean — no new warnings introduced.
- [ ] T055 [MVP] Verify full `dart test` (whole project) still passes — no regressions.
- [ ] T056 [MVP] Run `dart format .` per the task instructions (mandatory pre-commit step).
- [ ] T057 [MVP] Stage artifacts: `spec.md`, `plan.md`, `tasks.md`, `tdd/test-list.md`, `tdd/verification.md`, `tdd/red-evidence.md`, plugin source, plugin tests, edited `plugin_loader.dart`, `zfa_config.dart`, `plan_resolver.dart`.
- [ ] T058 [MVP] Commit with conventional prefixes:
  - `spec(029): spec, plan, tasks, tdd artifacts for AgentPlugin McpTool wrappers`
  - `feat(029): AgentPlugin — generate McpTool wrappers for every UseCase (--agent)`
  - `test(029): schema matrix, idempotency, collision, config precedence tests`
  - `fix(029): wire agent plugin into loader/config/plan-resolver` (if needed as a separate commit)
