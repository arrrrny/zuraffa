import 'mission.dart';

/// Ordered callback interface for policy concerns (FR-010).
abstract class AgentHook {
  String get id;
  bool enabled = true;

  /// Called when the mission starts (after state load, before agent loop).
  Future<void> onMissionStart(Mission mission) async {}

  /// Called when the mission ends (terminal state).
  Future<void> onMissionEnd(Mission mission, Object? outcome) async {}

  /// Called before a tool is invoked. May return a non-null
  /// [ToolDecision] to short-circuit the call (e.g. deny, replace args).
  Future<ToolDecision?> beforeToolCall(ToolCallContext ctx) async => null;

  /// Called after a tool returns. May modify [result].
  Future<Object?> afterToolCall(ToolCallContext ctx, Object? result) async =>
      result;
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
