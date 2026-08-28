/// Per-mission budget across four dimensions (FR-005).
class MissionBudget {
  const MissionBudget({
    this.maxCalls,
    this.maxWallClock,
    this.maxTokens,
    this.perToolClassMax = const <String, Duration>{},
  });

  /// Maximum number of tool calls. Null = unlimited.
  final int? maxCalls;

  /// Maximum wall-clock duration. Null = unlimited.
  final Duration? maxWallClock;

  /// Maximum cumulative token usage across all model interactions.
  /// Null = unlimited.
  final int? maxTokens;

  /// Maximum cumulative duration per tool class. Empty = unlimited.
  final Map<String, Duration> perToolClassMax;

  /// Sane framework defaults (used when the mission object omits budgets).
  static const MissionBudget defaults = MissionBudget(
    maxCalls: 100,
    maxWallClock: Duration(minutes: 10),
    maxTokens: 100000,
    perToolClassMax: <String, Duration>{
      'webview': Duration(minutes: 5),
      'scraper': Duration(minutes: 5),
    },
  );

  static const MissionBudget unlimited = MissionBudget();
}

/// Which budget dimension was breached (FR-006).
enum BudgetDimension {
  calls,
  wallClock,
  tokens,
  perToolClass,
}

/// Typed budget-exceeded event (FR-006).
class BudgetBreach {
  BudgetBreach({
    required this.dimension,
    required this.current,
    required this.max,
    required this.toolClass,
  });

  final BudgetDimension dimension;
  final num current;
  final num max;
  final String? toolClass;

  String get reason {
    switch (dimension) {
      case BudgetDimension.calls:
        return 'max-calls ($max) exceeded (current=$current)';
      case BudgetDimension.wallClock:
        return 'max-wall-clock (${max}ms) exceeded (current=${current}ms)';
      case BudgetDimension.tokens:
        return 'max-tokens ($max) exceeded (current=$current)';
      case BudgetDimension.perToolClass:
        return 'per-tool-class $toolClass (${max}ms) exceeded (current=${current}ms)';
    }
  }

  @override
  String toString() => 'BudgetBreach($reason)';
}

/// Tracks current usage against a [MissionBudget] and detects breaches.
class BudgetTracker {
  BudgetTracker(this.budget, {DateTime? startedAt})
      : _startedAt = startedAt ?? DateTime.now();

  final MissionBudget budget;
  final DateTime _startedAt;

  int _calls = 0;
  int _tokens = 0;
  final Map<String, Duration> _perToolClassUsed = <String, Duration>{};

  int get calls => _calls;
  int get tokens => _tokens;
  Duration get elapsed => DateTime.now().difference(_startedAt);

  /// Cumulative duration used by [toolClass] so far.
  Duration usedForClass(String toolClass) =>
      _perToolClassUsed[toolClass] ?? Duration.zero;

  /// Records a tool call of [toolClass] consuming [tokens] tokens and
  /// [duration] of per-tool-class time. Returns the first [BudgetBreach]
  /// detected, or null if no budget was breached.
  BudgetBreach? record({
    required String toolClass,
    int tokens = 0,
    Duration duration = Duration.zero,
  }) {
    _calls++;
    _tokens += tokens;
    _perToolClassUsed[toolClass] =
        (_perToolClassUsed[toolClass] ?? Duration.zero) + duration;

    // FR-005: check each dimension; emit the first breach (FR-006 + edge
    // case: "system emits one budget-exceeded event per breached limit and
    // cancels the mission on the first breach detected").
    if (budget.maxCalls != null && _calls > budget.maxCalls!) {
      return BudgetBreach(
        dimension: BudgetDimension.calls,
        current: _calls,
        max: budget.maxCalls!,
        toolClass: null,
      );
    }
    if (budget.maxTokens != null && _tokens > budget.maxTokens!) {
      return BudgetBreach(
        dimension: BudgetDimension.tokens,
        current: _tokens,
        max: budget.maxTokens!,
        toolClass: null,
      );
    }
    final elapsedMs = elapsed.inMilliseconds;
    if (budget.maxWallClock != null &&
        elapsedMs > budget.maxWallClock!.inMilliseconds) {
      return BudgetBreach(
        dimension: BudgetDimension.wallClock,
        current: elapsedMs,
        max: budget.maxWallClock!.inMilliseconds,
        toolClass: null,
      );
    }
    final perClassMax = budget.perToolClassMax[toolClass];
    if (perClassMax != null) {
      final usedMs = _perToolClassUsed[toolClass]!.inMilliseconds;
      if (usedMs > perClassMax.inMilliseconds) {
        return BudgetBreach(
          dimension: BudgetDimension.perToolClass,
          current: usedMs,
          max: perClassMax.inMilliseconds,
          toolClass: toolClass,
        );
      }
    }
    return null;
  }
}

/// Budget-degrade integration point (FR-013).
///
/// When the budget approaches a limit, the [MissionBudgetHook] invokes
/// this callback so the model client can switch to a lower-cost model
/// (or take other degradation action).
typedef BudgetDegradeCallback = void Function(BudgetBreach breach);

/// Callback fired when a budget breach is detected (FR-006).
typedef BudgetBreachCallback = void Function(BudgetBreach breach);
