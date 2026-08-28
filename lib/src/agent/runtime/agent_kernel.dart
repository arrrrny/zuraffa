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
    final state = existing ?? AgentState(missionId: mission.missionId);

    // FR-010: onMissionStart hooks.
    for (final hook in _hooks) {
      if (!hook.enabled) continue;
      await hook.onMissionStart(mission);
    }

    // Persist initial state.
    await _stateStorage.save(state);

    try {
      // FR-006: compose system prompt (called before each mission).
      // _promptComposer.compose(registry) — used by the LLM client.
      // (The actual LLM call is delegated to StatefulAgent.)
      await _llmClient.complete(_promptComposer.compose(registry));

      // FR-005, FR-013: delegate the agent loop entirely to StatefulAgent.
      await for (final event in statefulAgent.runStream(mission)) {
        yield event;
      }
    } catch (e, st) {
      yield MissionEventFailed(mission.missionId, e, st);
    } finally {
      // FR-010: onMissionEnd hooks.
      for (final hook in _hooks) {
        if (!hook.enabled) continue;
        await hook.onMissionEnd(mission, null);
      }
      await _stateStorage.save(state);
    }
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
