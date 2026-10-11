# Test List: 1344-agent-runtime-barrel-collisions

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1344-1 | a consumer fixture library declares its OWN `LlmClient`, `RiskTier`, `ToolResult`, `StatefulAgent`, `MissionTrace`, `MissionBudget` domain entities; a test file importing BOTH `package:zuraffa/zuraffa.dart` AND the fixture references all six names and they resolve unambiguously to the FIXTURE declarations (no ambiguous-import compile error) | FR-003, SC-3 | RED→GREEN |
| U-1344-2 | `package:zuraffa/agent.dart` exposes the agent runtime: referencing `LlmClient`, `RiskTier`, `ToolResult`, `StatefulAgent`, `AgentKernel` compiles and resolves to zuraffa's RUNTIME declarations; no ambiguity inside the dedicated barrel | FR-004, SC-4 | RED→GREEN |
| U-1344-3 | the dedicated agent barrel and a direct deep import (`package:zuraffa/src/agent/runtime/llm_client.dart`) expose the SAME `LlmClient` type (canonical Type identity) — backward compatibility for deep-import consumers | FR-004, SC-4 | RED→GREEN |
| U-1344-4 | `lib/zuraffa.dart` contains ZERO `agent/` path matches (the SC-1 grep gate, encoded as a source-level guard test) | FR-001, SC-1 | RED→GREEN |
| U-1344-5 | `lib/zuraffa/agent.dart` exists and carries the four former agent export sites (`ui_render`, `kernel/agent_kernel`, `policy/policy_shell`, `runtime/agent_runtime_plugin`) with their hide clauses | FR-002, SC-2 | RED→GREEN |
| U-1344-6 | the existing non-agent barrel surface is unchanged: the pre-existing barrel guard test (`test/pubignore_export_guard_test.dart`) stays green after the restructure | FR-005, SC-5 | GREEN (regression guard) |

## Layer contracts

```yaml
# fr: FR-001
lib/zuraffa.dart: zero src/agent export sites; zero "agent/" path references; pointer comment to the dedicated agent barrel
# fr: FR-002
lib/zuraffa/agent.dart: exports ../src/agent/{ui_render/ui_render,kernel/agent_kernel,policy/policy_shell,runtime/agent_runtime_plugin}.dart with the hide clauses verbatim from the former default-barrel sites
# fr: FR-003
test/fixtures/agent_collision_consumer_fixture.dart + test/agent/default_barrel_collision_test.dart: fixture-owned resolution for LlmClient, RiskTier, ToolResult, StatefulAgent, MissionTrace, MissionBudget
# fr: FR-004
test/agent/agent_barrel_access_test.dart: runtime-owned resolution via package:zuraffa/agent.dart; Type-identical to deep imports
```

## Key entities

- Consumer fixture entities mirror zuraffa_agent's own domain entities
  (specs 031/034/051): `LlmClient` (class), `RiskTier` (enum),
  `ToolResult` (class) — same NAMES, same kind, with fixture markers so the
  tests can prove WHICH declaration a reference resolved to.
- The dedicated barrel preserves the four hide clauses verbatim so the
  gated surface is byte-for-byte the surface the default barrel carried
  (kernel-vs-runtime `Mission`/`MissionEvent`/`AgentKernel` and
  ui_render-vs-policy `MissionTraceRecorder` conflicts stay resolved the
  same way).

## Red evidence protocol

Each RED→GREEN row must show the pre-fix failure mode before T4/T5 land:
- U-1344-1: ambiguous-import compile errors for every fixture name that the
  default barrel also exports (dart test compilation failure output).
- U-1344-2/U-1344-3: `package:zuraffa/agent.dart` does not exist →
  uri_does_not_exist compile failure.
- U-1344-4/U-1344-5: source gate assertions fail against the current barrel.
