# TDD Verification — AgentPlugin — McpTool Wrappers for UseCases

**Spec**: `specs/029-agent-plugin-mcp-wrappers/spec.md`
**Plan**: `specs/029-agent-plugin-mcp-wrappers/plan.md`
**Tasks**: `specs/029-agent-plugin-mcp-wrappers/tasks.md`
**Test List**: `specs/029-agent-plugin-mcp-wrappers/tdd/test-list.md`

**Feature Branch**: `029-agent-plugin-mcp-wrappers`
**Hard Dependency**: issue #384 (MCP runtime + `McpTool` base class) — landed at:
- `lib/src/core/module/mcp_tool.dart:159` (`abstract class McpTool`)
- `lib/src/core/module/mcp_tool.dart:35` (`class McpToolResult`)
- `lib/src/core/module/mcp_tool_registry.dart:17` (`class McpToolRegistry`)

---

## 1. TDD Discipline — Test-First Evidence

The SDD loop for spec 029 was driven through the standard red-green-refactor
cycle. Every behavior on the test list was first written as a failing test
(RED), then implemented to make it pass (GREEN), then refactored for clarity
without changing behavior (REFACTOR). The table below records, per behavior,
the test file, the test name, the initial RED state, and the final GREEN
state.

| FR / Behavior                                              | Test file                                       | Initial | Final  |
| ---------------------------------------------------------- | ----------------------------------------------- | :-----: | :----: |
| FR-001 plugin id `agent`                                   | `test/agent/plugin/agent_plugin_test.dart`      | RED     | GREEN  |
| FR-001 `PluginLoader.listPlugins` includes `agent`          | `test/agent/plugin/config_precedence_test.dart` | RED     | GREEN  |
| FR-002 `--agent` flag emits one tool per UseCase           | `test/agent/plugin/agent_plugin_test.dart`      | RED     | GREEN  |
| FR-003 flag-on + config-on → active                         | `test/agent/plugin/config_precedence_test.dart` | RED     | GREEN  |
| FR-003 flag-on + config-off → active (flag wins)           | `test/agent/plugin/config_precedence_test.dart` | RED     | GREEN  |
| FR-003 flag-off (`--no-agent`) + config-on → inactive       | `test/agent/plugin/config_precedence_test.dart` | RED     | GREEN  |
| FR-003 flag-off (no flag) + config-off → inactive           | `test/agent/plugin/config_precedence_test.dart` | RED     | GREEN  |
| FR-003 `agent: true` config enables without flag            | `test/agent/plugin/config_precedence_test.dart` | RED     | GREEN  |
| FR-004 introspect fixture Listing → 4 records               | `test/agent/plugin/usecase_introspector_test.dart` | RED  | GREEN  |
| FR-004 entity with no usecases → empty list                 | `test/agent/plugin/usecase_introspector_test.dart` | RED  | GREEN  |
| FR-004 entity with no usecase directory → empty list        | `test/agent/plugin/usecase_introspector_test.dart` | RED  | GREEN  |
| FR-005 generated tool files at `lib/src/agent/tools/`        | `test/agent/plugin/agent_plugin_test.dart`      | RED     | GREEN  |
| FR-005 entity with no usecases → empty file list            | `test/agent/plugin/agent_plugin_test.dart`      | RED     | GREEN  |
| FR-006 schema matrix (14 type cases)                        | `test/agent/plugin/schema_deriver_test.dart`     | RED     | GREEN  |
| FR-006 cycle: nested entity self-reference → `$ref`         | `test/agent/plugin/schema_deriver_test.dart`     | RED     | GREEN  |
| FR-007 manifest lists every tool                            | `test/agent/plugin/agent_plugin_test.dart`      | RED     | GREEN  |
| FR-007 risk tier `safe` by default, `admin` for `@AgentInternal` | `test/agent/plugin/agent_plugin_test.dart` | RED     | GREEN  |
| FR-008 regenerate → identical files (idempotency)          | `test/agent/plugin/agent_plugin_test.dart`      | RED     | GREEN  |
| FR-008 removed UseCase → tool file + manifest entry deleted | `test/agent/plugin/agent_plugin_test.dart`     | RED     | GREEN  |
| FR-008 mergeOrFresh idempotency (byte-for-byte)             | `test/agent/plugin/generated_marker_merger_test.dart` | RED | GREEN |
| FR-008 manual edits above marker survive regen             | `test/agent/plugin/generated_marker_merger_test.dart` | RED | GREEN |
| FR-008 manual edits below marker survive regen             | `test/agent/plugin/generated_marker_merger_test.dart` | RED | GREEN |
| FR-008 identical content without markers → idempotent rewrap | `test/agent/plugin/generated_marker_merger_test.dart` | RED | GREEN |
| FR-009 manual file without markers → `ManualFileConflictException` | `test/agent/plugin/agent_plugin_test.dart` | RED  | GREEN  |
| FR-009 manual file conflict (merger unit test)              | `test/agent/plugin/generated_marker_merger_test.dart` | RED | GREEN |
| FR-009 `ToolNameConflictException` names both entities     | `test/agent/plugin/tool_namespace_test.dart`    | RED     | GREEN  |
| FR-009 same verb across different entities → no collision   | `test/agent/plugin/tool_namespace_test.dart`    | RED     | GREEN  |

**Final tally**: 52 tests across 6 test files. All 52 pass. Zero skipped.

---

## 2. Test-Smell Rubric

Each test was inspected against the standard test-smell checklist; findings
recorded below.

| Smell                                            | Present? | Mitigation |
| ------------------------------------------------ | :------: | ---------- |
| No assertions (test runs but doesn't assert)    |   no     | Every test has at least one `expect(...)` against the spec's success criteria. |
| Assertion on implementation detail, not behavior |   no     | All assertions target public API surface (`AgentPlugin.generateWithContext`, `UseCaseIntrospector.introspect`, `SchemaDeriver.derive`, `mergeOrFresh`, `canonicalToolName`, `CollisionDetector.register`). No private state is reflected upon. |
| Single test covering multiple behaviors          |   no     | Each test name states exactly one FR/behavior. Test bodies verify that single behavior; setup is shared via `setUp`/helpers. |
| Brittle fixture (over-specified, breaks on minor change) | partial | The `writeFixtureUseCases` helper writes canonical zuraffa CRUD use case files. If the zuraffa `UseCase` base signature changes, fixtures must be updated; this is acceptable given the tight coupling to the UseCase convention. |
| Tests depend on execution order                  |   no     | Each test uses a fresh `Directory.systemTemp.createTemp('agent_plugin_...')` in `setUp`. No shared mutable state across tests. |
| Hidden sleeps / flaky timing                      |   no     | All tests are deterministic. No `Future.delayed` or wall-clock assertions. |
| Commented-out / skipped tests                    |   no     | Zero `skip:` annotations. Zero commented-out `expect(...)` calls. |
| `print` instead of `expect`                      |   no     | All verification uses `expect`. `print` appears only for informational runtime messages in `UseCaseIntrospector` (the "no usecases" message is part of the spec contract — Edge Case "Entity with no UseCases"). |
| Tests that pass for the wrong reason              |   no     | Schema matrix tests assert the EXACT JSON Schema shape (e.g. `{'type': 'string', 'format': 'date-time'}`), not `contains` loose matching. Idempotency tests assert byte-for-byte equality, not "approximately equal". |

**Result**: No blocking test smells. The "partial" finding on fixture
brittleness is a documented and accepted trade-off, not a defect.

---

## 3. Mutation Analysis

A formal mutation-testing run was not in scope for this feature (no
`mutation-test` config registered for the agent plugin directory). However,
the test design encodes the equivalent guarantees through three structural
properties:

1. **Exact-shape schema assertions** — `schema_deriver_test.dart` asserts the
   full JSON Schema map for each of the 14 type-matrix cases. A mutation that
   changes any field (`type`, `format`, `items`, `additionalProperties`,
   `nullable`, `enum`, `properties`, `required`, `description`) would flip
   at least one assertion from green to red.

2. **Byte-level idempotency assertion** — `generated_marker_merger_test.dart`
   line 65 (`mergeOrFresh is idempotent: regenerating twice yields identical
   bytes`) compares the full `String` output of two regeneration passes with
   `expect(second, first)`. A mutation that adds, removes, or reorders a
   single byte in the merged output fails this test.

3. **Precedence matrix completeness** — `config_precedence_test.dart`
   exercises all four `(--agent|∅) × (agent:true|false)` combinations and
   asserts the plugin-active/inactive outcome in each case. A mutation that
   flips any one of the four precedence rules fails exactly one case while
   leaving the other three green — localizing the regression.

---

## 4. Acceptance Criteria Coverage

| SC    | Requirement                                                              | Proven by                                                                                                                                                                                                  | Verdict |
| ----- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-----: |
| SC-001 | `zfa make Demo --preset=crud --agent` produces tool wrappers + manifest that compile & are callable through MCP runtime. | `agent_plugin_test.dart` asserts: (a) one tool file per UseCase exists at `lib/src/agent/tools/{entity}_{verb}_tool.dart`, (b) the manifest barrel lists every tool, (c) `dart analyze` on the generated source is clean, (d) the runtime smoke path resolves the UseCase from `getIt` and returns a `McpToolResult`. | PROVEN |
| SC-002 | Schema derivation correct across the full type matrix.                  | `schema_deriver_test.dart` — 14 type-matrix tests cover `String`, `int`, `double`, `num`, `bool`, `DateTime`, `List<T>`, `Map<String,V>`, nullable `T?`, nullable `List<T>?`, enum, nested entity, `SignalResult<T>` unwrapping, `Future<T>` unwrapping, and unresolvable generic. The self-referencing nested-entity test asserts a `$ref` is emitted (cycle guard). | PROVEN |
| SC-003 | Regeneration idempotent — byte-for-byte, manual extensions outside markers survive. | (a) `mergeOrFresh is idempotent: regenerating twice yields identical bytes` (byte equality). (b) `manual edits above GENERATED marker survive regeneration` (content survival). (c) `manual edits below GENERATED marker survive regeneration` (content survival). (d) `AgentPlugin — SC-003 idempotency regenerate produces identical files (byte-for-byte)` (end-to-end via `AgentPlugin.generateWithContext`). (e) `removed UseCase deletes its tool file + manifest entry` (stale cleanup). | PROVEN |
| SC-004 | `--agent` flag and project config interact correctly, flag takes precedence. | `config_precedence_test.dart` — 4 explicit combinations + 2 default-state assertions. Covers flag-on × config-on, flag-on × config-off (flag wins), flag-off × config-on (flag wins), flag-off × config-off. | PROVEN |

**All four success criteria are PROVEN by mechanical tests, not by manual inspection.**

---

## 5. Verification Commands

The following commands were run to produce the evidence in this file:

```bash
# 029-scope analyzer — must be zero issues
dart analyze lib/src/agent/plugin/ test/agent/plugin/ \
  lib/src/cli/plugin_loader.dart lib/src/config/zfa_config.dart \
  lib/src/core/planning/plan_resolver.dart
# → "No issues found!"

# 029-scope tests — must be 52/52 green
dart test test/agent/plugin/
# → "All tests passed!" (52 tests)

# Whole-agent regression — must remain green
dart test test/agent/
# → "All tests passed!" (196 tests including 029)

# Format check (mandatory per spec)
dart format .
```

---

## 6. Out-of-Scope & Follow-ups

The following items are documented in the spec as **out of scope for v1** and
are NOT covered by tests in this feature:

- Cross-project tool discovery (single-project generation only).
- Runtime-level tool permission enforcement (manifest is a static barrel).
- `@AgentInternal` annotation definition (Zorphy concern; this plugin reads
  it via substring match in the source file, not via AST resolution).
- `Params.fromJson` auto-discovery for the tool `_buildParams` method. The
  generated `_buildParams` passes the args map through; UseCases whose
  Params type requires typed construction must be hand-wired in a
  manually-written subclass outside the GENERATED markers.

These follow-ups are tracked by the spec's Assumptions section and are not
TDD regressions.
