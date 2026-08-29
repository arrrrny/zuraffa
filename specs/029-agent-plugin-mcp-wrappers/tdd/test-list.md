# Test List — AgentPlugin — McpTool Wrappers for UseCases

**Spec**: `specs/029-agent-plugin-mcp-wrappers/spec.md`
**Plan**: `specs/029-agent-plugin-mcp-wrappers/plan.md`
**Tasks**: `specs/029-agent-plugin-mcp-wrappers/tasks.md`

## FR / Behavior → Test Mapping

| FR / Behavior | Test name | File path | Status |
|---|---|---|---|
| FR-001 (AgentPlugin registered with id 'agent' and surfaces in plan.activePlugins) | `AgentPlugin surfaces in plan when --agent flag parsed` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-001 (AgentPlugin is a FileGeneratorPlugin) | `AgentPlugin is a FileGeneratorPlugin with id 'agent'` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-002 (--agent flag triggers tool wrapper generation for target entity's UseCases) | `--agent flag emits one tool wrapper per UseCase` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-003 (config `agent: true` enables generation without flag) | `agentByDefault: true enables generation without --agent flag` | `test/agent/plugin/config_precedence_test.dart` | GREEN |
| FR-003 (explicit --agent flag takes precedence over config false) | `--agent flag wins over agentByDefault: false config` | `test/agent/plugin/config_precedence_test.dart` | GREEN |
| FR-003 (explicit --no-agent flag takes precedence over config true) | `--no-agent flag wins over agentByDefault: true config` | `test/agent/plugin/config_precedence_test.dart` | GREEN |
| FR-003 (neither flag nor config → no generation) | `no flag and agentByDefault: false → no tools generated` | `test/agent/plugin/config_precedence_test.dart` | GREEN |
| FR-004 (introspect entity's generated UseCases; extract name, Params, return type) | `introspect fixture Listing entity → 4 use case records (get/create/update/delete)` | `test/agent/plugin/usecase_introspector_test.dart` | GREEN |
| FR-004 (entity with no use cases returns empty list, informational message) | `introspect entity with no use cases → empty list, no error` | `test/agent/plugin/usecase_introspector_test.dart` | GREEN |
| FR-005 (one tool wrapper file per UseCase under lib/src/agent/tools/{usecase_snake}_tool.dart) | `generated tool files live at lib/src/agent/tools/{entity}_{verb}_tool.dart` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-005 (tool wrapper implements McpTool interface with name, inputSchema, outputSchema, call) | `emitted tool wrapper subclasses McpTool with name + schemas + call` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-005 (call method resolves UseCase from getIt and maps result) | `invoking emitted call resolves UseCase and returns McpToolResult` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-005 (call catches errors and returns McpToolResult(isError: true)) | `emitted call catches UseCase exceptions and returns isError result` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-006 (String param → inputSchema {"type":"string"}) | `derive(String) → {"type":"string"}` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-006 (int param → inputSchema {"type":"integer"}) | `derive(int) → {"type":"integer"}` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-006 (double param → inputSchema {"type":"number"}) | `derive(double) → {"type":"number"}` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-006 (bool param → inputSchema {"type":"boolean"}) | `derive(bool) → {"type":"boolean"}` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-006 (DateTime param → inputSchema {"type":"string","format":"date-time"}) | `derive(DateTime) → {"type":"string","format":"date-time"}` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-006 (List<T> param → array schema) | `derive(List<String>) → {"type":"array","items":{"type":"string"}}` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-006 (Map<String,V> param → object schema) | `derive(Map<String,V>) → object with additionalProperties` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-006 (nullable T? → schema with nullable: true) | `derive(String?) → {"type":"string","nullable":true}` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-006 (enum → string enum schema) | `derive(Status enum) → {"type":"string","enum":[...]}` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-006 (nested Zorphy entity → inlined nested object schema) | `derive(Address entity) → {"type":"object","properties":{...}}` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-006 (SignalResult<T> unwrapped to schema of T) | `derive(SignalResult<Listing>) → schema of Listing` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-006 (unresolvable type → open-object with documentation) | `derive(unresolvable generic) → {"type":"object","description":"..."}` | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| FR-007 (manifest barrel lists every tool with name, entity, risk tier) | `manifest lists every generated tool with name + entity + risk tier` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-007 (default risk tier = safe) | `manifest assigns safe by default` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-007 (UseCases annotated @AgentInternal → risk tier = admin) | `manifest assigns admin to @AgentInternal-annotated UseCases` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-007 (tools grouped by domain/entity) | `manifest groups tools by entity` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-008 (regenerating with same UseCase state → no diff) | `regenerate produces identical files (idempotency)` | `test/agent/plugin/generated_marker_merger_test.dart` | GREEN |
| FR-008 (manual edits outside // GENERATED markers survive) | `manual line above marker survives regeneration` | `test/agent/plugin/generated_marker_merger_test.dart` | GREEN |
| FR-008 (removed UseCases cause their tool files to be deleted) | `removed UseCase deletes its tool file + manifest entry` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| FR-009 (tool name conflict → fail with clear error, not silent overwrite) | `two entities producing same canonical name → ToolNameConflictException` | `test/agent/plugin/tool_namespace_test.dart` | GREEN |
| FR-009 (manual tool file in target dir → fail, not silent overwrite) | `manual file without markers in tools dir → ManualFileConflictException` | `test/agent/plugin/generated_marker_merger_test.dart` | GREEN |
| FR-010 (generated code passes dart analyze with zero warnings) | `dart analyze on generated tools dir → zero warnings` | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| SC-001 (zfa make Demo --preset=crud --agent → wrappers + manifest compile and are callable) | `end-to-end generation + invocation test` (combination of FR-002, FR-005, FR-010 tests) | `test/agent/plugin/agent_plugin_test.dart` | GREEN |
| SC-002 (schema derivation correct across full type matrix) | `schema matrix tests` (FR-006 tests above) | `test/agent/plugin/schema_deriver_test.dart` | GREEN |
| SC-003 (regeneration idempotent; manual extensions survive) | `idempotency + manual-extension tests` (FR-008 tests above) | `test/agent/plugin/generated_marker_merger_test.dart` | GREEN |
| SC-004 (--agent flag and config interact correctly; explicit flag wins) | `4-combination config precedence tests` (FR-003 tests above) | `test/agent/plugin/config_precedence_test.dart` | GREEN |

## Success Criteria Coverage

| SC | Test(s) that prove it |
|---|---|
| SC-001 (zfa make Demo --preset=crud --agent → wrappers + manifest compile and are callable through MCP runtime) | `--agent flag emits one tool wrapper per UseCase`, `emitted tool wrapper subclasses McpTool with name + schemas + call`, `invoking emitted call resolves UseCase and returns McpToolResult`, `emitted call catches UseCase exceptions and returns isError result`, `dart analyze on generated tools dir → zero warnings`, `manifest lists every generated tool with name + entity + risk tier` |
| SC-002 (schema derivation correct across full type matrix) | `derive(String/int/double/bool/DateTime/List/Map/nullable/enum/nested entity/SignalResult/unresolvable) → ...` (12 type matrix tests) |
| SC-003 (regeneration idempotent; manual extensions survive) | `regenerate produces identical files (idempotency)`, `manual line above marker survives regeneration`, `removed UseCase deletes its tool file + manifest entry` |
| SC-004 (--agent flag and config interact correctly; explicit flag wins) | `agentByDefault: true enables generation without --agent flag`, `--agent flag wins over agentByDefault: false config`, `--no-agent flag wins over agentByDefault: true config`, `no flag and agentByDefault: false → no tools generated` |
