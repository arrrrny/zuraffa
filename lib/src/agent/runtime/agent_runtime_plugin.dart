/// Agent Runtime Plugin — `AgentRuntimePlugin` + `McpToolProvider` SPI.
///
/// In-proc kernel host over `dart_agent_core`. Assembles a flat,
/// collision-safe `McpToolRegistry` from three sources (SPI providers,
/// generated usecase tools, remote MCP servers). The kernel delegates the
/// agent loop entirely to `StatefulAgent.runStream` (FR-013 — no loop
/// duplication). Composes the system prompt from playbook + tool manifests,
/// wires `FallbackLLMClient` as the default LLM client, persists per-mission
/// session state, supports ordered `AgentHook` registration for policy
/// concerns, and exposes `kernel.status()`.
///
/// Pure-Dart — no `package:flutter` imports. See
/// `specs/028-agent-runtime-plugin/` for the full spec.
library;

export 'mcp_tool_provider.dart';
export 'mcp_tool_registry.dart';
export 'mission.dart';
export 'mission_event.dart';
export 'agent_hook.dart';
export 'stateful_agent.dart';
export 'llm_client.dart';
export 'system_prompt_composer.dart';
export 'state_storage.dart';
export 'kernel_status.dart';
export 'agent_kernel.dart';
export 'agent_runtime_plugin_class.dart';
