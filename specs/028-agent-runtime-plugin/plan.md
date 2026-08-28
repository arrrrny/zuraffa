# Implementation Plan: Agent Runtime Plugin

**Branch**: `028-agent-runtime-plugin` | **Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/028-agent-runtime-plugin/spec.md`

## Summary

Builds `AgentRuntimePlugin` plus an `McpToolProvider` SPI that hosts the agent kernel in-process over `dart_agent_core`. Assembles a flat, collision-safe `McpToolRegistry` from SPI providers, generated usecase tools, and remote MCP servers; delegates the agent loop entirely to `StatefulAgent.runStream`; persists per-mission session state and exposes `kernel.status()`. The kernel accepts a `Mission` object as its single input, composes the system prompt from playbook + tool manifests, and wires `FallbackLLMClient` as the default LLM client. Ordered `AgentHook` registration supports policy concerns (gating, budget, trace) at defined lifecycle points.

## Technical Context

**Language/Version**: Dart 3.13+ (SDK 3.11+ compatible) — pure-Dart package.

**Primary Dependencies**: `zuraffa core`; `dart_agent_core`'s `StatefulAgent`, `McpManager`, `LocalMcpTransport`, `FallbackLLMClient`, `AgentState`, `FileStateStorage` (referenced via SPI; this delivery provides local interfaces so the kernel can be tested without a real `dart_agent_core` import).

**Storage**: Per-mission session state persisted via `FileStateStorage` (FR-009).

**Testing**: `dart test`. Tests under `test/agent/runtime/...`. Pure Dart.

**Project Type**: library subsystem.

**Constraints**:
- Pure Dart — no Flutter imports.
- No new dependencies in `pubspec.yaml`.
- MUST NOT duplicate agent-loop logic from `dart_agent_core` (FR-013).
- `McpToolProvider` SPI is the discovery mechanism — no reflection.

## Constitution Check

Pass — no constitution violations. Pure-Dart subsystem; no Flutter dependency; no new external dependencies.

## Project Structure

```text
specs/028-agent-runtime-plugin/
├── plan.md
├── tasks.md
└── tdd/
    ├── test-list.md
    ├── red-evidence.md
    └── verification.md

lib/src/agent/runtime/
├── agent_runtime_plugin.dart  # Barrel + AgentRuntimePlugin
├── mcp_tool_provider.dart     # FR-001 (McpToolProvider SPI)
├── mcp_tool_registry.dart     # FR-003, FR-012 (flat, collision-safe)
├── mcp_tool_context.dart       # FR-001 (context for buildTools)
├── agent_kernel.dart          # FR-005, FR-008 (kernel; delegates to StatefulAgent)
├── agent_hook.dart            # FR-010 (ordered policy hooks)
├── mission.dart               # FR-008 (Mission object)
├── kernel_status.dart         # FR-011 (kernel.status())
├── system_prompt_composer.dart # FR-006
├── llm_client.dart           # FR-007 (FallbackLLMClient interface)
└── state_storage.dart         # FR-009 (AgentState / FileStateStorage interface)

test/agent/runtime/
├── mcp_tool_registry_test.dart
├── mcp_tool_provider_test.dart
├── agent_kernel_test.dart
├── kernel_status_test.dart
└── agent_runtime_plugin_test.dart
```

## Phases

### Phase 0 — Research
No external research required. SPI pattern is standard; `dart_agent_core` is referenced via abstract interfaces so the kernel works whether or not the real package is on the path.

### Phase 1 — Design
- **McpToolProvider** (SPI): `abstract class { String namespace; List<McpTool> buildTools(McpToolContext ctx); }`. Registered via DI (constructor injection by `AgentRuntimePlugin`).
- **McpToolRegistry**: flat `Map<String, McpTool>` keyed by `"$namespace.$toolName"`. `register(tool)` throws on collision (FR-012). Built from three sources: SPI providers (in-proc), generated usecase tools, remote MCP servers (via `McpManager`).
- **AgentKernel**: holds the registry, the LLM client, the hook list. `runMission(Mission)` streams typed `MissionEvent`s; delegates the actual loop to `StatefulAgent.runStream` (or to a fallback when `dart_agent_core` is not present — verified via SPI).
- **AgentHook**: `abstract class { String id; bool enabled; Future<void> onMissionStart(Mission); Future<void> onMissionEnd(Mission, outcome); Future<ToolDecision> beforeToolCall(ToolCallContext); Future<ToolResult> afterToolCall(ToolCallContext, ToolResult); }`.
- **KernelStatus**: structured report with `providers: Map<String, ProviderInfo>`, `toolCountPerNamespace: Map<String, int>`, `remoteServerHealth: Map<String, Health>`.

### Phase 2 — Tasks
See `tasks.md`.
