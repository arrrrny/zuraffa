/// Dedicated barrel for the Zuraffa agent runtime (issue #1344).
///
/// ## Why this barrel exists
///
/// zuraffa 6.2.x's agent runtime (`src/agent/**`: kernel, policy, runtime,
/// shell, ui_render) was originally re-exported from the default
/// `package:zuraffa/zuraffa.dart` barrel. That collided with ecosystem
/// packages — notably `zuraffa_agent` — whose own domain entities carry
/// generic agent-domain names (`LlmClient`, `RiskTier`, `ToolResult`, and
/// the wider agent-domain name class): every file importing both packages
/// failed with ambiguous-import errors at load time (5 files / 8 error
/// sites in `zuraffa_agent` alone).
///
/// The runtime is therefore gated behind THIS dedicated import — the same
/// split pattern as Flutter's material vs widgets libraries. The default
/// barrel no longer re-exports any of it; nothing else changed.
///
/// ## What is exported
///
/// The export surface below is byte-for-byte the surface the default
/// barrel used to carry for the agent runtime (same four entry libraries,
/// same `hide` clauses), so consumers migrating from the old default-barrel
/// imports only swap the import URI:
///
/// ```dart
/// import 'package:zuraffa/agent.dart';
/// ```
///
/// - **ui_render** (spec 023): the `ui.render` tool + streaming UI event
///   channel + action-loop closure. Agents author a component tree
///   validated against the UI Vocabulary Schema; user interactions route
///   back as semantic actions. `ValidationResult`, `ValidationError`, and
///   `MissionTraceRecorder` are hidden: `ValidationResult`/`ValidationError`
///   would collide with the plugin-lifecycle subsystem when combined with
///   the default barrel, and `MissionTraceRecorder` is defined by BOTH the
///   ui_render plugin and the policy shell (unrelated features that
///   coincidentally share the name — the policy shell's wins, as it did in
///   the default barrel). Consumers needing ui_render's variants can import
///   `package:zuraffa/src/agent/ui_render/ui_vocabulary_schema.dart`
///   directly.
/// - **kernel** (spec 026): mission coalescing, cancellation, partial
///   salvage, idempotency cache — the kernel's efficiency + safety core.
///   `CancelToken`, `Mission`, `MissionEvent`, `MissionEventCompleted`,
///   and `MissionEventFailed` are hidden so the runtime plugin's
///   declarations of those names win, exactly as in the old default barrel.
/// - **policy shell** (spec 027): ToolGatingHook, MissionBudgetHook,
///   MissionTraceRecorder — the framework-default safety/governance layer.
///   `ToolCallContext` is hidden (the same mechanism the default barrel
///   always used).
/// - **runtime plugin** (spec 028): AgentRuntimePlugin + McpToolProvider
///   SPI. `McpTool`, `AgentHook`, `McpToolRegistry`, and `AgentKernel` are
///   hidden — `McpTool`/`McpToolRegistry` belong to the core MCP module in
///   the default barrel, and the kernel's `AgentKernel` declaration wins
///   over the runtime's same-named class, preserving the arbitration the
///   default barrel performed.
///
/// Consumers importing the runtime's source files directly
/// (`package:zuraffa/src/agent/...`) are unaffected: those declarations are
/// identical to what this barrel exposes.
library;

// ── 023-agent-plugin-ui-render — agent-authored live, interactive UI ──
// `ui.render` tool + streaming UI event channel + action-loop closure.
// Pure-Dart (no package:flutter import anywhere in this subtree).
export '../src/agent/ui_render/ui_render.dart'
    hide ValidationResult, ValidationError, MissionTraceRecorder;

// ── 026-agent-kernel-mission — mission coalescing, cancellation, partial-salvage ──
// The agent kernel's efficiency + safety core. Identical missions coalesce
// into one execution via a composite key (spark type + normalized value +
// country + strategy variant); mid-execution cancellation triggers a grace
// period that disposes resources and salvages partials as `cancelled_partial`;
// an idempotency cache serves repeated submissions within TTL. Single-isolate
// assumption documented; MissionExecutor is the multi-isolate extension point.
// Pure-Dart (no package:flutter import anywhere in this subtree).
export '../src/agent/kernel/agent_kernel.dart'
    hide
        CancelToken,
        Mission,
        MissionEvent,
        MissionEventCompleted,
        MissionEventFailed;

// ── 027-agent-policy-shell — ToolGatingHook, MissionBudgetHook, MissionTraceRecorder ──
// Framework-default safety/governance layer. Tool permission registry
// (safe/confirm/admin) evaluated before every tool call; four-dimension
// mission budgets (calls, wall-clock, tokens, per-tool-class seconds) with
// typed budget-exceeded events and cancellation; hashed-argument Mission
// Trace JSON with concurrent-streaming integrity and an oversized-result
// guard. All hooks composable and individually disableable. Pure-Dart.
export '../src/agent/policy/policy_shell.dart' hide ToolCallContext;

// ── 028-agent-runtime-plugin — AgentRuntimePlugin + McpToolProvider SPI ──
// In-proc kernel host over dart_agent_core. McpToolProvider SPI for device
// packages to self-describe; McpToolRegistry assembles a flat, collision-safe
// tool registry from SPI providers + generated usecase tools + remote MCP
// servers. AgentKernel delegates the agent loop entirely to
// StatefulAgent.runStream (no loop duplication — FR-013). Composes system
// prompt from playbook + tool manifests; wires FallbackLLMClient as default;
// persists per-mission session state via FileStateStorage; supports ordered
// AgentHook registration for policy concerns; exposes kernel.status().
// Pure-Dart (no package:flutter import anywhere in this subtree).
export '../src/agent/runtime/agent_runtime_plugin.dart'
    hide McpTool, AgentHook, McpToolRegistry, AgentKernel;
