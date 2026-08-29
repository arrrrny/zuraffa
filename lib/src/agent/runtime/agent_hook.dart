import 'mission.dart';

/// Ordered callback interface for policy concerns (FR-010).
abstract class AgentHook {
  String get id;
  bool enabled = true;

  /// Called when the mission starts (after state load, before agent loop).
  Future<void> onMissionStart(Mission mission) async {}

  /// Called when the mission ends (terminal state).
  Future<void> onMissionEnd(Mission mission, Object? outcome) async {}

  /// Called before a tool is invoked, by `AgentKernel.invokeTool` — the
  /// hook-gated entry point the kernel hands to
  /// [StatefulAgent.runStream] as `invokeTool`.
  ///
  /// Returning a [ToolDecisionDeny] short-circuits the call and surfaces a
  /// [ToolDeniedException] to the agent loop. Returning null (or
  /// [ToolDecisionAllow]) lets the call proceed.
  Future<ToolDecision?> beforeToolCall(ToolCallContext ctx) async => null;

  /// Called after a tool returns, by `AgentKernel.invokeTool`. The returned
  /// value replaces the tool result and is fed to the next hook in order.
  Future<Object?> afterToolCall(ToolCallContext ctx, Object? result) async =>
      result;
}

/// Thrown by `AgentKernel.invokeTool` when an [AgentHook] denies a tool
/// call via [ToolDecisionDeny] (FR-010).
class ToolDeniedException implements Exception {
  ToolDeniedException(this.canonicalName, this.reason, this.hookId);

  /// Canonical name (`"$namespace.$toolName"`) of the denied tool.
  final String canonicalName;

  /// Human-readable reason supplied by the hook.
  final String reason;

  /// Id of the hook that denied the call.
  final String hookId;

  @override
  String toString() =>
      'ToolDeniedException: $canonicalName denied by hook "$hookId" — $reason';
}

/// Context for a tool call passed to [AgentHook.beforeToolCall].
class ToolCallContext {
  ToolCallContext({
    required this.missionId,
    required this.toolName,
    required this.args,
  });
  final String missionId;
  final String toolName;
  final Map<String, Object?> args;
}

/// Decision returned by [AgentHook.beforeToolCall] to short-circuit a
/// tool call.
sealed class ToolDecision {
  const ToolDecision();
}

final class ToolDecisionAllow extends ToolDecision {
  const ToolDecisionAllow();
}

final class ToolDecisionDeny extends ToolDecision {
  const ToolDecisionDeny(this.reason);
  final String reason;
}
