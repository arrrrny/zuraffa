import 'llm_client.dart';
import 'mission.dart';
import 'mission_event.dart';

/// Invokes a registry tool by canonical name (`"$namespace.$toolName"`).
///
/// The kernel hands one of these to [StatefulAgent.runStream] so every tool
/// call made by the delegated loop passes through the kernel's
/// [AgentHook.beforeToolCall]/[AgentHook.afterToolCall] policy chain
/// (FR-010).
typedef ToolInvoker = Future<Object?> Function(
  String canonicalName,
  Map<String, Object?> args,
);

/// SPI for `dart_agent_core`'s `StatefulAgent` (FR-005, FR-013).
///
/// The [AgentKernel] delegates the agent loop entirely to this interface;
/// it does NOT implement the loop itself (FR-013 — no duplication). A real
/// `dart_agent_core` installation provides the implementation; tests provide
/// a stub.
abstract class StatefulAgent {
  /// Streams typed events for [mission]. The kernel orchestrates the
  /// tool registry + hooks around this call and supplies:
  ///
  /// * [systemPrompt] — composed by `SystemPromptComposer` from the playbook
  ///   and the registry tool manifests (FR-006). Implementations MUST use it
  ///   as the system message of the loop.
  /// * [llmClient] — the client wired by `AgentRuntimePlugin` (FR-007). The
  ///   loop owns the completion calls; the kernel makes none itself.
  /// * [invokeTool] — hook-gated tool invocation (FR-010). Implementations
  ///   MUST route tool calls through it rather than calling
  ///   `McpTool.invoke` directly.
  Stream<MissionEvent> runStream(
    Mission mission, {
    String? systemPrompt,
    LlmClient? llmClient,
    ToolInvoker? invokeTool,
  });
}

/// A stub [StatefulAgent] that emits a start + completed event pair.
/// Used in tests and as a fallback when `dart_agent_core` is not on the
/// path.
class StubStatefulAgent implements StatefulAgent {
  StubStatefulAgent({this.outcome, this.toolCalls = const <String>[]});

  final Object? outcome;

  /// Canonical tool names this stub "calls" during the mission.
  final List<String> toolCalls;

  int callCount = 0;

  /// The system prompt the kernel passed in (FR-006).
  String? receivedSystemPrompt;

  /// The LLM client the kernel passed in (FR-007).
  LlmClient? receivedLlmClient;

  @override
  Stream<MissionEvent> runStream(
    Mission mission, {
    String? systemPrompt,
    LlmClient? llmClient,
    ToolInvoker? invokeTool,
  }) async* {
    callCount++;
    receivedSystemPrompt = systemPrompt;
    receivedLlmClient = llmClient;
    yield MissionEventStarted(mission.missionId, DateTime.now());
    for (final canonical in toolCalls) {
      yield MissionEventToolCallStart(
        mission.missionId,
        canonical,
        const <String, Object?>{},
      );
      final result = invokeTool == null
          ? null
          : await invokeTool(canonical, const <String, Object?>{});
      yield MissionEventToolCallResult(mission.missionId, canonical, result);
    }
    yield MissionEventCompleted(mission.missionId, outcome);
  }
}
