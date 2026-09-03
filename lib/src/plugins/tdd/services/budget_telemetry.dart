/// `BudgetTelemetry` — the wall-clock budget telemetry of spec
/// 069-corpus-economics (issue #916): every corpus-lane verdict JSON
/// carries the measured budget so CI can see WHERE the minutes went
/// (wall-clock per step, suite seconds, mutant count) instead of a
/// bare pass/fail.
///
/// The recorded shape (JSON, snake_case — the corpus progress/ledger
/// house convention):
///
/// ```json
/// {
///   "wall_clock_ms": {
///     "run": 1234, "verify": 567, "total": 1801
///   },
///   "suite_seconds": 12,
///   "mutant_count": 8
/// }
/// ```
///
/// - `wall_clock_ms` — cumulative milliseconds per corpus step kind
///   (`run`, `verify`) plus `total` for the whole lane invocation;
/// - `suite_seconds` — seconds the lane spent inside spawned suite
///   processes (the preflight/re-proof/batch invocations — the number
///   the baseline cache and the incremental re-proof are judged by);
/// - `mutant_count` — mutants the lane's verify gates assessed (killed
///   + survived + timed-out; the mutation audit's raw workload).
///
/// All numbers are MEASURED (Stopwatch around the real spawn), never
/// estimated; the accumulator is additive so per-feature shards merge
/// into a lane total simply by summing.
library;

import 'dart:convert';

/// The per-step wall-clock accumulators (milliseconds).
class WallClockBudget {
  WallClockBudget() : _millis = <String, int>{};

  final Map<String, int> _millis;

  /// Add [millis] to step [name] (e.g. `run`, `verify`).
  void addMillis(String name, int millis) {
    _millis[name] = (_millis[name] ?? 0) + millis;
  }

  /// Record the elapsed [duration] under step [name].
  void addDuration(String name, Duration duration) =>
      addMillis(name, duration.inMilliseconds);

  /// The accumulated milliseconds for step [name] (0 when absent).
  int millisOf(String name) => _millis[name] ?? 0;

  /// Every accumulated step name.
  List<String> get stepNames => _millis.keys.toList()..sort();

  Map<String, int> toJson() => {
    for (final name in stepNames) name: _millis[name]!,
  };
}

/// The budget telemetry accumulator for one corpus-lane invocation.
class BudgetTelemetry {
  BudgetTelemetry()
    : startedAt = DateTime.now(),
      wallClock = WallClockBudget(),
      _suiteSecondsTotal = 0.0,
      _mutantCount = 0;

  /// The lane invocation start (wall-clock reference).
  final DateTime startedAt;

  /// Cumulative per-step wall-clock milliseconds.
  final WallClockBudget wallClock;

  double _suiteSecondsTotal;
  int _mutantCount;

  /// Seconds spent inside spawned suite processes (whole seconds;
  /// the accumulation itself is double-precision so sub-second spawn
  /// durations add up instead of rounding away).
  int get suiteSeconds => _suiteSecondsTotal.round();

  /// Add [seconds] to the suite time budget.
  void addSuiteSeconds(double seconds) =>
      _suiteSecondsTotal += seconds >= 0 ? seconds : 0;

  /// The mutants assessed by the lane's verify gates.
  int get mutantCount => _mutantCount;

  /// Record [count] assessed mutants (killed + survived + timed-out).
  void addMutants(int count) => _mutantCount += count;

  /// The total lane wall-clock so far (milliseconds since [startedAt]).
  int get totalMillis => DateTime.now().difference(startedAt).inMilliseconds;

  /// The machine-readable JSON block (the verdict embedding contract):
  /// `{"wall_clock_ms": {...}, "suite_seconds": n, "mutant_count": n}`.
  Map<String, dynamic> toJson() => {
    'wall_clock_ms': {...wallClock.toJson(), 'total': totalMillis},
    'suite_seconds': suiteSeconds,
    'mutant_count': mutantCount,
  };

  /// The indented JSON encoding (for the verdict file).
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Merge [other] into this accumulator (shard-lane merging: the
  /// totals are additive by design).
  void merge(BudgetTelemetry other) {
    for (final name in other.wallClock.stepNames) {
      wallClock.addMillis(name, other.wallClock.millisOf(name));
    }
    _suiteSecondsTotal += other._suiteSecondsTotal;
    _mutantCount += other.mutantCount;
  }

  /// Parse a telemetry JSON block (the inverse of [toJson]); null when
  /// [json] is not the telemetry shape (a missing/foreign block never
  /// crashes a verdict reader).
  static BudgetTelemetry? fromJson(Map<String, dynamic> json) {
    final wallRaw = json['wall_clock_ms'];
    final suite = json['suite_seconds'];
    final mutants = json['mutant_count'];
    if (wallRaw is! Map<String, dynamic> || suite is! num || mutants is! num) {
      return null;
    }
    final telemetry = BudgetTelemetry();
    for (final entry in wallRaw.entries) {
      if (entry.value is num && entry.key != 'total') {
        telemetry.wallClock.addMillis(entry.key, (entry.value as num).round());
      }
    }
    telemetry._suiteSecondsTotal = suite.toDouble();
    telemetry._mutantCount = mutants.round();
    return telemetry;
  }
}
