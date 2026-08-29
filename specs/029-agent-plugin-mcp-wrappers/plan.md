# Implementation Plan: AgentPlugin — McpTool Wrappers for UseCases

**Branch**: `029-agent-plugin-mcp-wrappers` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/029-agent-plugin-mcp-wrappers/spec.md` (read-only — `/speckit.specify` was intentionally NOT run; the existing draft is the sole spec input).

## Summary

Builds `AgentPlugin` (id `agent`) as a Zuraffa `FileGeneratorPlugin` that introspects an entity's already-generated UseCases and emits one MCP tool wrapper file per UseCase under `lib/src/agent/tools/{usecase_snake}_tool.dart`, plus a `lib/src/agent/tools/manifest.dart` barrel cataloguing every tool with its owning entity and a default risk tier (`safe`, or `admin` for UseCases annotated with `@AgentInternal`).

Each generated wrapper:
- Implements `McpTool` from `lib/src/core/module/mcp_tool.dart` (issue #384's runtime base class — verified present at `lib/src/core/module/mcp_tool.dart:159`).
- Declares a stable namespaced name (`{namespace}.{entity}.{verb}` — e.g. `app.listing.compose`) and a JSON Schema `inputSchema` derived from the UseCase's `Params` type.
- Declares an `outputSchema` derived from the UseCase's return type across the full matrix: primitives, enums, nested Zorphy entities, `List<T>`, nullable `T?`, and `DateTime` (mapped to ISO-8601 string). Unresolvable types fall back to an open-object schema with a documentation note.
- Implements `call(Map<String, dynamic>)` that resolves the UseCase from `getIt` (or `ZuraffaContainer`) and maps the result into an `McpToolResult` (text + structured `data`).

Opt-in is wired through three integration points so the existing `zfa make` planner surfaces it without bespoke plumbing:
1. `PluginLoader._plugins()` — registers `AgentPlugin` so `make_command._addPluginOptions` auto-adds the `--agent` flag (negatable, default `true`) and `--no-agent` mutes it.
2. `ZfaConfig._builtinPluginDefaults` — adds `'agent': false` so the plugin is dormant by default.
3. `PlanResolver._selectionFromOptions` — adds `if (_isTrue(options['agent'])) selection.add('agent');` so the flag activates the plugin through the same path as every other plugin flag. The existing config-default loop (`config?.isPluginEnabledByDefault(plugin.id)`) and the existing `--no-agent` exclusion loop give us the four precedence combinations for free (FR-003).

Idempotency (FR-008) is enforced by a `GeneratedMarkerMerger` that, for every emit:
1. If the target file exists and contains `// GENERATED - DO NOT EDIT ... // END GENERATED` markers, replaces ONLY that block — manual code above/below the markers is preserved byte-for-byte.
2. If the target file exists WITHOUT markers and the new content would replace non-whitespace content, throws `ManualFileConflictException` (FR-009) — refuses to silently clobber hand-written work.
3. If the target file does not exist, writes it fresh with markers.

After emitting, the plugin sweeps the target directory and removes any tool file whose UseCase is no longer present (only files that contain `// GENERATED` markers are deleted — manual tool files are never touched).

Tool-name collisions across entities (FR-009) are detected before any file is written: the plugin maintains an in-memory `Set<String>` of canonical names (`{namespace}.{entity}.{verb}`) across the active generation pass; the first duplicate throws `ToolNameConflictException` naming both entities.

## Technical Context

**Language/Version**: Dart 3.13+ (SDK `^3.11.0`). Pure-Dart package — no Flutter imports anywhere in the new code.

**Primary Dependencies** (all already in `pubspec.yaml`):
- `code_builder: ^4.11.1` — AST-based Dart emission for tool wrapper files and manifest barrel.
- `dart_style: ^3.1.12` — Dart formatting (already wrapped by `SpecLibrary`).
- `analyzer: 14.1.0` — AST introspection of the entity's generated UseCase files to extract `Params` fields, return types, and `@AgentInternal` annotation.
- `path: ^1.9.1` — paths under `lib/src/agent/tools/`.
- Runtime base class `McpTool` from `lib/src/core/module/mcp_tool.dart` (issue #384 — present).
- DI surface `getIt` from `get_it: ^9.2.1` — referenced by emitted `call` methods; not invoked at generation time.

**Storage**: Code generation only — no runtime state. Output files live under `lib/src/agent/tools/`.

**Testing**: `dart test`. Tests under `test/agent/plugin/...` and `test/agent/plugin/_fixtures/` for fixture UseCases. Pure Dart.

**Project Type**: library subsystem (codegen plugin) + thin runtime invocation glue (emitted wrappers).

**Constraints**:
- Pure Dart — no Flutter imports in the plugin OR in any emitted wrapper file.
- No new external dependencies in `pubspec.yaml`.
- MUST NOT modify the `McpTool` contract (issue #384's deliverable is the contract; we only emit subclasses).
- MUST NOT silently overwrite manually-written tool files (FR-009).
- MUST produce `dart analyze`-clean output on a fresh scaffold (FR-010).
- Generated wrapper `call` method MUST NOT throw across the MCP boundary — it MUST catch and return `McpToolResult(isError: true, text: ...)`.

## Constitution Check

Pass — no constitution violations. Pure-Dart plugin subsystem; no Flutter dependency; no new external dependencies; no `dependency_overrides` reintroduced.

## Project Structure

```text
specs/029-agent-plugin-mcp-wrappers/
├── plan.md
├── tasks.md
├── spec.md  (existing — read-only input)
├── checklists/
│   └── requirements.md  (existing)
└── tdd/
    ├── test-list.md
    ├── red-evidence.md
    └── verification.md

lib/src/
├── agent/
│   ├── plugin/
│   │   ├── agent_plugin.dart            # AgentPlugin (FileGeneratorPlugin, id='agent')
│   │   ├── usecase_introspector.dart   # AST-based UseCase metadata extraction
│   │   ├── schema_deriver.dart         # Dart type → JSON Schema mapping
│   │   ├── tool_wrapper_emitter.dart   # code_builder emitter for one McpTool subclass
│   │   ├── manifest_emitter.dart       # code_builder emitter for the barrel manifest
│   │   ├── generated_marker_merger.dart# idempotent write-merge (FR-008, FR-009)
│   │   └── tool_namespace.dart         # canonical name + collision detection (FR-009)
│   └── tools/                          # ← OUTPUT TARGET (created on first generation)
│       ├── {entity}_{verb}_tool.dart   # one wrapper per UseCase
│       └── manifest.dart               # barrel manifest
├── cli/
│   └── plugin_loader.dart              # ← EDITED: register AgentPlugin
├── config/
│   └── zfa_config.dart                 # ← EDITED: 'agent': false in _builtinPluginDefaults
└── core/
    └── planning/
        └── plan_resolver.dart          # ← EDITED: _selectionFromOptions adds 'agent'

test/
└── agent/
    └── plugin/
        ├── agent_plugin_test.dart              # end-to-end generation integration test (SC-001)
        ├── schema_deriver_test.dart            # full type matrix (SC-002)
        ├── generated_marker_merger_test.dart   # idempotency + manual-extension survival (SC-003)
        ├── tool_namespace_test.dart             # collision detection (FR-009)
        ├── usecase_introspector_test.dart       # AST extraction of Params + return types
        ├── config_precedence_test.dart          # 4-combination flag/config matrix (SC-004)
        └── _fixtures/                           # hand-written fixture UseCases for tests
            ├── listing.dart
            └── order.dart
```

## Phases

### Phase 1: Foundation (FR-001)

Wire the plugin into the loader, config defaults, and planner so `zfa make Foo --agent` and `agent: true` config both surface the plugin through the existing planner pipeline.

- T001 Create `lib/src/agent/plugin/agent_plugin.dart` — empty `AgentPlugin` shell implementing `FileGeneratorPlugin` with `id='agent'`, `name='Agent Plugin'`, `version='1.0.0'`. No-op `generateWithContext` returning `[]`.
- T002 Register `AgentPlugin(...)` in `PluginLoader._plugins()` (lib/src/cli/plugin_loader.dart).
- T003 Add `'agent': false` to `ZfaConfig._builtinPluginDefaults` (lib/src/config/zfa_config.dart).
- T004 Add `if (_isTrue(options['agent'])) selection.add('agent');` to `PlanResolver._selectionFromOptions` (lib/src/core/planning/plan_resolver.dart).
- T005 Test: `zfa make Foo --agent` activates the plugin (smoke test asserting `AgentPlugin` is in `plan.activePlugins`).

### Phase 2: UseCase Introspection (FR-004)

Extract `UseCaseMetadata { className, paramsType, paramsFields, returnType, isAgentInternal }` from an entity's generated UseCase files.

- T006 Define `UseCaseMetadata` value type.
- T007 Define `UseCaseIntrospector` that walks `lib/src/domain/usecases/{domain}/` for files matching `*_{entitySnake}_usecase.dart` and parses each with `analyzer`'s `parseFile` → `CompilationUnit`. Extract the `class X extends UseCase<ReturnT, ParamsT>` declaration, walk `ParamsT` (resolved via `ClassDeclaration.member.fields`), and detect `@AgentInternal()` annotation.
- T008 Test: introspect a fixture entity with `Get`, `Create`, `Update`, `Delete` use cases; assert 4 metadata records with correct param/return types.
- T009 Edge: introspect an entity with NO use cases — return empty list, log informational message (NOT an error — Edge Cases in spec).

### Phase 3: Schema Derivation (FR-006, SC-002)

Map Dart types to JSON Schema across the full matrix.

- T010 Define `SchemaDeriver` that takes a `DartType` (or a string type reference for codegen-side resolution) and returns `Map<String, dynamic>` JSON Schema.
- T011 Implement primitive mappings: `String`→`{"type":"string"}`, `int`→`{"type":"integer"}`, `double`/`num`→`{"type":"number"}`, `bool`→`{"type":"boolean"}`.
- T012 Implement `DateTime` → `{"type":"string","format":"date-time"}`.
- T013 Implement `List<T>` → `{"type":"array","items":{...T...}}` and `Map<String,V>` → `{"type":"object","additionalProperties":{...V...}}`.
- T014 Implement nullable `T?` → schema for `T` with `"nullable": true`.
- T015 Implement enum → `{"type":"string","enum":[...]}` (resolve enum values via AST).
- T016 Implement nested Zorphy entity → inline its fields as nested object schema (recursive descent, with cycle guard).
- T017 Implement `SignalResult<T>` unwrapping → schema for `T`.
- T018 Implement unresolvable / generic-with-unresolved-typearg → open-object `{"type":"object","description":"Unresolvable type X"}` + log warning (Edge Case in spec).
- T019 Test: schema matrix test covering every supported type, asserting the produced JSON Schema shape exactly matches expected output (SC-002).

### Phase 4: Tool Wrapper Emission (FR-005, SC-001)

Generate one `McpTool` subclass file per UseCase.

- T020 Define `ToolWrapperEmitter` that takes a `UseCaseMetadata` + entity name + namespace and produces a `code_builder.Library` emitting a `class {Verb}{Entity}Tool extends McpTool` with `name`, `description`, `inputSchema` (computed by `SchemaDeriver`), `outputSchema`, and a `call(arguments)` method that resolves the UseCase from `getIt` and returns an `McpToolResult`.
- T021 Generate namespaced tool name: `{namespace}.{entitySnake}.{verb}` (e.g. `app.listing.compose` — note: `compose` is the verb for a `CreateListing` use case; verb derived from the UseCase class name prefix).
- T022 Emit `call` body: parse `arguments` map into the UseCase's Params type via JSON-decode-and-cast, resolve UseCase via `getIt<{UseCaseClassName}>()`, invoke `useCase.call(params)`, wrap result into `McpToolResult(text: jsonEncode(result), data: {...})`. Wrap entire body in `try/catch` returning `McpToolResult(isError: true, text: e.toString())` on failure.
- T023 Test: generate a tool wrapper for a fixture UseCase; assert the emitted file parses (Dart analyzer) and `dart analyze` is clean.
- T024 Test: invoke the emitted `call` method via the MCP interface (in-process: instantiate the wrapper, set up a fake DI with the fixture UseCase, call with sample args, assert a valid `McpToolResult`) — SC-001 runtime leg.

### Phase 5: Manifest Barrel (FR-007)

Emit a single `manifest.dart` barrel listing all generated tools with domain grouping and risk tier.

- T025 Define `ManifestEmitter` that takes the list of `(toolName, entityName, riskTier)` tuples and produces a `code_builder.Library` emitting a `const List<ToolManifestEntry> agentTools = [...]` plus per-entity grouped maps (`Map<String, List<ToolManifestEntry>>` keyed by entity).
- T026 Define `ToolManifestEntry { name, entity, riskTier }` runtime model in `lib/src/agent/plugin/manifest_entry.dart`.
- T027 Default risk tier is `safe`; `UseCaseMetadata.isAgentInternal == true` → `admin`.
- T028 Test: generate the manifest for a 2-entity fixture; assert it lists every tool, groups by entity, and assigns correct risk tiers.

### Phase 6: Idempotent Merge (FR-008, FR-009, SC-003)

The `GeneratedMarkerMerger` writer that preserves manual edits outside `// GENERATED` markers.

- T029 Define `GeneratedMarkerMerger` with `Future<String> mergeOrFresh(String existing, String newGeneratedContent)`.
- T030 If existing file does NOT contain `// GENERATED` markers and has non-whitespace content that differs from the new generated content → throw `ManualFileConflictException(path, diff)`.
- T031 If existing file DOES contain markers → replace ONLY the block between (and including) the markers; preserve everything above and below verbatim.
- T032 If existing file does NOT exist → return `newGeneratedContent` wrapped with markers.
- T033 Test: generate, record SHA256 of each file, regenerate → assert SHAs identical (SC-003 idempotency leg).
- T034 Test: inject a manual `// Hello from a developer` line above the GENERATED block in a generated tool file; regenerate → assert manual line preserved and generated block refreshed (SC-003 manual-extension leg).
- T035 Test: hand-write a tool file with no markers in the target path; run generation → assert `ManualFileConflictException` thrown naming the conflicting path (FR-009).

### Phase 7: Collision Detection (FR-009)

- T036 Define `ToolNamespace` with `canonicalOf(namespace, entity, verb)` and a `CollisionDetector` that accumulates canonical names across the active generation pass.
- T037 First duplicate → throw `ToolNameConflictException(canonical, entityA, entityB)` (NOT silently overwrite).
- T038 Test: fixture with two entities both producing `app.item.create` → generation fails with `ToolNameConflictException`.
- T039 Test: same verb across DIFFERENT entities (e.g. `app.listing.create` and `app.order.create`) → NO collision.

### Phase 8: Stale Tool Cleanup (FR-008)

- T040 After successful emission, sweep `lib/src/agent/tools/` for files containing `// GENERATED` markers whose name does NOT match any newly generated tool filename → delete (only marker-tagged files are eligible for deletion — manual files never touched).
- T041 Test: generate 4 tools, remove one UseCase, regenerate → assert the orphaned tool file is deleted and the manifest no longer references it.

### Phase 9: Opt-in Config Precedence (FR-003, SC-004)

- T042 Already wired in Phase 1 (T003 + T004 + existing plan_resolver exclusion path). Verify end-to-end with the four-combination test.
- T043 Test: 4-combination matrix — (flag on / config on), (flag on / config off), (flag off / config on), (flag off / config off) — assert generation occurs exactly when expected, and `--no-agent` always wins over `agent: true` config.
- T044 Test: `zfa make Foo --preset=crud` WITHOUT `--agent` and WITHOUT `agent: true` → no tool files generated (User Story 4 Acceptance Scenario 1).

### Phase 10: Code Quality (FR-010)

- T045 Run `dart analyze` on the generated fixture output; assert zero warnings.
- T046 Run `dart format --set-exit-if-changed lib/` on the new plugin code and on a freshly generated fixture; assert no diff (files are pre-formatted).
- T047 Run `dart test` for the full new test surface; assert all GREEN.

## Testing Strategy

TDD red-green-refactor (per the TDD extension's contract):
1. Write the test-list (this `tdd/test-list.md`) BEFORE any implementation.
2. Write the test files. Run them → RED. Capture evidence in `tdd/red-evidence.md`.
3. Implement the minimal code to flip RED → GREEN.
4. Refactor (deduplicate, extract helpers) under GREEN.
5. Verify in `tdd/verification.md` with the test-smell rubric.

Test layout:
- `test/agent/plugin/agent_plugin_test.dart` — end-to-end generation + invocation (SC-001).
- `test/agent/plugin/schema_deriver_test.dart` — type matrix (SC-002).
- `test/agent/plugin/generated_marker_merger_test.dart` — idempotency + manual-extension survival (SC-003).
- `test/agent/plugin/config_precedence_test.dart` — 4-combination flag/config matrix (SC-004).
- `test/agent/plugin/tool_namespace_test.dart` — collision detection (FR-009).
- `test/agent/plugin/usecase_introspector_test.dart` — AST extraction.
- `test/agent/plugin/_fixtures/` — hand-written fixture UseCases and entities for tests.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `analyzer` resolution of Zorphy entity fields requires the entity source file to be on disk (it is — generated by entity plugin, runs before agent plugin via dependsOn) | Add `dependsOn: ['usecase']` so the agent plugin runs strictly after usecase generation. |
| Circular references between nested Zorphy entities during schema derivation | `SchemaDeriver` carries a `Set<String> _visiting` stack; if a type name recurs, emit a `$ref` to the previously-derived schema (cycle-safe). |
| Manual edits in generated tool files outside `// GENERATED` markers | `GeneratedMarkerMerger` preserves everything outside the marker block; manual edits inside the marker block are clobbered with a documented warning. |
| Tool name conflicts across entities | `CollisionDetector` throws before any file is written; the entire generation pass aborts with a clear multi-entity error. |
| Stale tool files after UseCase removal | Post-emission sweep deletes only files with `// GENERATED` markers — manual tool files in `lib/src/agent/tools/` are never deleted. |
