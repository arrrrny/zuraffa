import 'dart:async';

import 'agent_hook.dart';
import 'kernel_status.dart';
import 'llm_client.dart';
import 'mission.dart';
import 'mission_event.dart';
import 'mcp_tool_registry.dart';
import 'state_storage.dart';
import 'stateful_agent.dart';
import 'system_prompt_composer.dart';

/// The thin orchestrator that bridges the tool registry to
/// `dart_agent_core`'s `StatefulAgent` (FR-005, FR-013 — no loop
/// duplication).
class AgentKernel {
  AgentKernel({
    required this.registry,
    required this.statefulAgent,
    LlmClient? llmClient,
    SystemPromptComposer? promptComposer,
    FileStateStorage? stateStorage,
    List<AgentHook> hooks = const <AgentHook>[],
  })  : _llmClient = llmClient ?? FallbackLLMClient(),
        _promptComposer = promptComposer ?? SystemPromptComposer(),
        _stateStorage = stateStorage ?? InMemoryFileStateStorage(),
        _hooks = <AgentHook>[...hooks];

  final McpToolRegistry registry;
  final StatefulAgent statefulAgent;
  final LlmClient _llmClient;
  final SystemPromptComposer _promptComposer;
  final FileStateStorage _stateStorage;
  final List<AgentHook> _hooks;

  /// Streams typed [MissionEvent]s for [mission] (FR-008).
  ///
  /// Persists session state on start/end (FR-009). Runs ordered
  /// [AgentHook] callbacks at lifecycle points (FR-010). Delegates the
  /// agent loop entirely to [StatefulAgent.runStream] (FR-005, FR-013).
  Stream<MissionEvent> runMission(Mission mission) async* {
    // FR-009: load state.
    final existing = await _stateStorage.load(mission.missionId);
    var state = existing ?? AgentState(missionId: mission.missionId);

    // FR-010: onMissionStart hooks.
    for (final hook in _hooks) {
      if (!hook.enabled) continue;
      await hook.onMissionStart(mission);
    }

    // Persist initial state.
    await _stateStorage.save(state);

    Object? outcome;
    try {
      // FR-006: compose the system prompt before each mission and hand it to
      // the loop — the kernel itself makes no LLM call, the agent owns them
      // (FR-007, FR-013).
      final systemPrompt = _promptComposer.compose(registry);

      // FR-005, FR-013: delegate the agent loop entirely to StatefulAgent.
      final events = statefulAgent.runStream(
        mission,
        systemPrompt: systemPrompt,
        llmClient: _llmClient,
        invokeTool: (canonical, args) =>
            invokeTool(mission.missionId, canonical, args),
      );

      await for (final event in events) {
        // FR-009: record real progress so the persisted state is not empty.
        if (event is MissionEventToolCallStart) {
          state = state.copyWith(
            steps: <String>[...state.steps, event.toolName],
          );
        } else if (event is MissionEventCompleted) {
          outcome = event.outcome;
        }
        yield event;
      }
    } catch (e, st) {
      yield MissionEventFailed(mission.missionId, e, st);
    } finally {
      // FR-010: onMissionEnd hooks.
      for (final hook in _hooks) {
        if (!hook.enabled) continue;
        await hook.onMissionEnd(mission, outcome);
      }
      await _stateStorage.save(state);
    }
  }

  /// Invokes the registry tool [canonicalName] through the hook policy
  /// chain (FR-010).
  ///
  /// This is the callback the kernel passes to [StatefulAgent.runStream] as
  /// `invokeTool`, so tool gating applies to the delegated loop. Hooks run in
  /// registration order; the first [ToolDecisionDeny] aborts the call with a
  /// [ToolDeniedException]. [AgentHook.afterToolCall] may rewrite the result.
  Future<Object?> invokeTool(
    String missionId,
    String canonicalName,
    Map<String, Object?> args,
  ) async {
    final ctx = ToolCallContext(
      missionId: missionId,
      toolName: canonicalName,
      args: args,
    );

    for (final hook in _hooks) {
      if (!hook.enabled) continue;
      final decision = await hook.beforeToolCall(ctx);
      if (decision is ToolDecisionDeny) {
        throw ToolDeniedException(canonicalName, decision.reason, hook.id);
      }
    }

    final tool = registry.lookup(canonicalName);
    if (tool == null) {
      throw ArgumentError.value(
        canonicalName,
        'canonicalName',
        'not registered in the tool registry',
      );
    }

    var result = await tool.invoke(args);
    for (final hook in _hooks) {
      if (!hook.enabled) continue;
      result = await hook.afterToolCall(ctx, result);
    }
    return result;
  }

  /// Returns the kernel status (FR-011).
  KernelStatus status({
    Map<String, String> providers = const <String, String>{},
    Map<String, String> remoteServerHealth = const <String, String>{},
  }) {
    return buildStatus(
      registry,
      providers: providers,
      remoteServerHealth: remoteServerHealth,
    );
  }

  /// Registered hooks (for testing).
  List<AgentHook> get hooks => List<AgentHook>.unmodifiable(_hooks);
}
