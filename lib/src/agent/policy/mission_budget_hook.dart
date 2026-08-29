import 'mission_budget.dart';
import 'policy_hook.dart';

/// Policy hook that enforces four-dimension mission budgets (FR-005,
/// FR-006). On breach, emits a typed [BudgetBreach] event via
/// [onBreach] and cancels the mission by returning a
/// [HookDecisionCancelMission].
class MissionBudgetHook extends PolicyHook {
  MissionBudgetHook({
    required this.budget,
    required this.onBreach,
    this.degradeCallback,
  });

  @override
  String get id => 'mission_budget';

  final MissionBudget budget;
  final BudgetBreachCallback onBreach;
  final BudgetDegradeCallback? degradeCallback;

  /// Per-mission trackers (one per missionId).
  final Map<String, BudgetTracker> _trackers = <String, BudgetTracker>{};

  /// Per-mission set of already-reported breach dimensions, so the same
  /// breached limit fires its event exactly once (FR-005/FR-006: "one
  /// budget-exceeded event per breached limit").
  final Map<String, Set<BudgetDimension>> _reported =
      <String, Set<BudgetDimension>>{};

  void _report(String missionId, BudgetBreach breach) {
    final seen = _reported.putIfAbsent(missionId, () => <BudgetDimension>{});
    if (!seen.add(breach.dimension)) return;
    onBreach(breach);
    degradeCallback?.call(breach);
  }

  BudgetTracker trackerFor(String missionId) {
    return _trackers.putIfAbsent(missionId, () => BudgetTracker(budget));
  }

  @override
  Future<void> onMissionStart(String missionId) async {
    _trackers[missionId] = BudgetTracker(budget);
    _reported.remove(missionId);
  }

  @override
  Future<void> onMissionEnd(String missionId) async {
    _trackers.remove(missionId);
    _reported.remove(missionId);
  }

  @override
  Future<HookDecision> beforeToolCall(ToolCallContext ctx) async {
    final tracker = trackerFor(ctx.missionId);

    // Check the calls dimension before the call (FR-006: cancel before
    // any further tool calls execute).
    if (budget.maxCalls != null && tracker.calls >= budget.maxCalls!) {
      final breach = BudgetBreach(
        dimension: BudgetDimension.calls,
        current: tracker.calls,
        max: budget.maxCalls!,
        toolClass: null,
      );
      _report(ctx.missionId, breach);
      return HookDecisionCancelMission(breach.reason);
    }

    // Check the wall-clock dimension.
    if (budget.maxWallClock != null) {
      final elapsedMs = tracker.elapsed.inMilliseconds;
      if (elapsedMs > budget.maxWallClock!.inMilliseconds) {
        final breach = BudgetBreach(
          dimension: BudgetDimension.wallClock,
          current: elapsedMs,
          max: budget.maxWallClock!.inMilliseconds,
          toolClass: null,
        );
        _report(ctx.missionId, breach);
        return HookDecisionCancelMission(breach.reason);
      }
    }

    // Check the tokens dimension.
    if (budget.maxTokens != null && tracker.tokens >= budget.maxTokens!) {
      final breach = BudgetBreach(
        dimension: BudgetDimension.tokens,
        current: tracker.tokens,
        max: budget.maxTokens!,
        toolClass: null,
      );
      _report(ctx.missionId, breach);
      return HookDecisionCancelMission(breach.reason);
    }

    // Check per-tool-class dimension (if a class max is set).
    if (budget.perToolClassMax.containsKey(ctx.toolClass)) {
      final used = tracker.usedForClass(ctx.toolClass);
      final max = budget.perToolClassMax[ctx.toolClass]!;
      if (used >= max) {
        final breach = BudgetBreach(
          dimension: BudgetDimension.perToolClass,
          current: used.inMilliseconds,
          max: max.inMilliseconds,
          toolClass: ctx.toolClass,
        );
        _report(ctx.missionId, breach);
        return HookDecisionCancelMission(breach.reason);
      }
    }

    return const HookDecisionAllow();
  }

  @override
  Future<ToolResult> afterToolCall(
    ToolCallContext ctx,
    ToolResult result,
  ) async {
    final tracker = trackerFor(ctx.missionId);
    final breach = tracker.record(
      toolClass: ctx.toolClass,
      tokens: result.tokenUsage,
      duration: result.duration,
    );
    if (breach != null) {
      _report(ctx.missionId, breach);
    }
    return result;
  }
}
