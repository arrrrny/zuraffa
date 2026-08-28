# Test List — Agent Runtime Plugin

**Spec**: `specs/028-agent-runtime-plugin/spec.md`
**Plan**: `specs/028-agent-runtime-plugin/plan.md`

| FR / Behavior | Test name | File path | Status |
|---|---|---|---|
| FR-001 (McpToolProvider SPI: namespace + buildTools) | `buildTools returns tools under a namespace` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-001 (McpToolContext — DI accessor) | `DI context passes dependencies to providers (FR-002)` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-002 (DI/engine discovery) | `buildTools returns tools under a namespace` (provider invoked via constructor injection) | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-003 (assembles registry from SPI + usecase + remote) | `assembles registry from SPI + usecase + remote sources` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-003 (registers and looks up by canonical name) | `registers and looks up tools by canonical name` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-004 (in-proc serving path — zero IPC) | — (structural — registry is a single in-process map; no IPC by construction) | — | GREEN |
| FR-005 + FR-013 (kernel delegates to StatefulAgent.runStream) | `3-tool mission streams typed events (SC-001)`, `zero agent-loop duplication (FR-013)` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-006 (system prompt from playbook + tool manifests) | `composes playbook + tool manifests` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-007 (FallbackLLMClient default) | `uses primary when available`, `falls back to secondary on primary failure`, `returns empty string when no clients configured (degraded)` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-008 (Mission object as kernel input) | `3-tool mission streams typed events (SC-001)` (mission passed to kernel.runMission) | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-009 (session state per-mission) | `persists and loads state per missionId`, `load returns null when no state` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-010 (ordered AgentHook registration) | `hooks run in registration order on mission start`, `disabled hooks are skipped` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-011 (kernel.status) | `reports providers, tool counts, and remote health` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-012 (collision detection + prevention) | `namespace collision throws (FR-012)`, `namespace collision prevents silent overwrite (FR-012, SC-002)`, `different namespaces do NOT collide` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| FR-013 (no agent-loop duplication) | `zero agent-loop duplication (FR-013)` (verified by StatefulAgent.callCount == 1) | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| SC-001 (3-tool mission streams events, no duplication) | `3-tool mission streams typed events (SC-001)` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |
| SC-002 (remote SSE tools merged + collision prevented) | `remote SSE tools merged with collision prevention (SC-002)`, `namespace collision prevents silent overwrite (FR-012, SC-002)` | `test/agent/runtime/agent_runtime_plugin_test.dart` | GREEN |

## Success Criteria Coverage

| SC | Test(s) that prove it |
|---|---|
| SC-001 (3-tool mission with 1 SPI + 1 usecase streams typed events; zero loop duplication) | `3-tool mission streams typed events (SC-001)`, `zero agent-loop duplication (FR-013)` |
| SC-002 (remote SSE tools merged + collision prevented) | `remote SSE tools merged with collision prevention (SC-002)`, `namespace collision prevents silent overwrite (FR-012, SC-002)` |
| SC-003 (test McpToolProvider discovered via DI) | `DI context passes dependencies to providers (FR-002)`, `buildTools returns tools under a namespace` |
| SC-004 (kernel.status() accurate) | `reports providers, tool counts, and remote health` |
