import 'dart:async';

/// Risk tier for a tool call (FR-001).
enum RiskLevel {
  /// Auto-executes without user intervention.
  safe,

  /// Blocks until user approves; denies on timeout.
  confirm,

  /// Denied for non-internal missions; allowed for internal missions.
  admin,
  ;

  /// Returns the most-restrictive of `this` and `other` (FR-001 edge case:
  /// conflicting entries → most-restrictive wins).
  RiskLevel mostRestrictive(RiskLevel other) {
    if (this == other) return this;
    // admin > confirm > safe
    if (index > other.index) return this;
    return other;
  }
}

/// Status of a tool call as recorded in the trace (FR-007).
enum ToolCallStatus {
  pending,
  executing,
  completed,
  failed,
  cancelled,
}

/// Outcome of a tool call evaluation.
sealed class HookDecision {
  const HookDecision();
}

final class HookDecisionAllow extends HookDecision {
  const HookDecisionAllow();
}

final class HookDecisionDeny extends HookDecision {
  const HookDecisionDeny(this.reason);
  final String reason;
}

final class HookDecisionNeedsConfirmation extends HookDecision {
  const HookDecisionNeedsConfirmation(this.prompt);
  final String prompt;
}

final class HookDecisionCancelMission extends HookDecision {
  const HookDecisionCancelMission(this.reason);
  final String reason;
}

/// Context passed to a [PolicyHook] for each tool call (FR-006).
class ToolCallContext {
  ToolCallContext({
    required this.missionId,
    required this.toolName,
    required this.args,
    required this.isInternalMission,
    required this.toolAllowlist,
    required this.toolClass,
    this.tokenUsage = 0,
  });

  final String missionId;
  final String toolName;
  final Map<String, Object?> args;
  final bool isInternalMission;
  final Set<String>? toolAllowlist;
  final String toolClass;
  final int tokenUsage;
}

/// Result returned by a tool.
class ToolResult {
  ToolResult({required this.payload, this.size, this.tokenUsage = 0});

  final Object? payload;
  final int? size;
  final int tokenUsage;

  int get effectiveSize =>
      size ??
      (payload is String
          ? (payload as String).length
          : payload.toString().length);
}

/// A composable policy hook that intercepts the agent loop (FR-011).
///
/// Hooks are registered with a [PolicyShell] and run in registration order.
/// Each can be individually disabled via [enabled].
abstract class PolicyHook {
  /// Stable identifier for this hook (e.g. `tool_gating`, `mission_budget`,
  /// `mission_trace`).
  String get id;

  /// Whether this hook is currently active. Disabled hooks are skipped by
  /// the [PolicyShell].
  bool enabled = true;

  /// Called before a tool is invoked. Returns a [HookDecision] that the
  /// shell uses to allow / deny / cancel the call.
  Future<HookDecision> beforeToolCall(ToolCallContext ctx) async {
    return const HookDecisionAllow();
  }

  /// Called after a tool has returned. May modify [result] (e.g., the
  /// oversized-result guard swaps in an [ArtifactReference]).
  Future<ToolResult> afterToolCall(
    ToolCallContext ctx,
    ToolResult result,
  ) async {
    return result;
  }

  /// Called once before the mission starts.
  Future<void> onMissionStart(String missionId) async {}

  /// Called once when the mission ends (terminal state).
  Future<void> onMissionEnd(String missionId) async {}
}
