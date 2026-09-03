/// `BudgetTelemetry` — wall-clock, suite-seconds, and mutant-count
/// budget telemetry for the corpus lane's JSON verdicts (spec
/// 069-corpus-economics, T003; issue #916's "budget telemetry
/// (wall-clock per step, suite seconds, mutant count) in JSON
/// verdicts").
///
/// The corpus runner records every per-feature step spawn's wall clock
/// (`run` / `verify`), parses the mutant counts from each verify
/// step's machine line (`mutation: gate=… killed=… survived=…
/// timed_out=…`), aggregates the suite seconds, and writes ONE JSON
/// verdict object at the end of the lane:
///
/// ```json
/// {
///   "schema": "corpus.budget.v1",
///   "shard": "2/4" | null,
///   "started_at": "…ISO-8601…",
///   "finished_at": "…ISO-8601…",
///   "wall_clock_ms": 123456,
///   "features": 7,
///   "result": "complete",
///   "steps": [
///     {"feature": "f2", "step": "run", "wall_clock_ms": 40123, "outcome": "complete"},
///     {"feature": "f2", "step": "verify", "wall_clock_ms": 9001, "outcome": "pass"}
///   ],
///   "suite_seconds": 49,
///   "mutants": {"killed": 12, "survived": 0, "timed_out": 1}
/// }
/// ```
///
/// CI enforces the ≤ 30 min full / ≤ 10 min sharded budgets against
/// these REAL numbers (never a wall-clock estimate). Mutant counts are
/// never fabricated: a verify output without the machine line
/// contributes nothing.
library;

import 'dart:convert';
import 'dart:io';

/// The mutant counts parsed from one verify step's machine line.
class MutantCounts {
  const MutantCounts({
    required this.killed,
    required this.survived,
    required this.timedOut,
  });

  final int killed;
  final int survived;
  final int timedOut;
}

/// One recorded step's budget line.
class BudgetStepRecord {
  const BudgetStepRecord({
    required this.feature,
    required this.step,
    required this.elapsed,
    required this.outcome,
  });

  final String feature;
  final String step;
  final Duration elapsed;
  final String outcome;

  Map<String, dynamic> toJson() => {
    'feature': feature,
    'step': step,
    'wall_clock_ms': elapsed.inMilliseconds,
    'outcome': outcome,
  };
}

class BudgetTelemetry {
  BudgetTelemetry._({required this.startedAt, required this.shard});

  /// Start the wall clock. [shard] is the lane's `--shard <i>/<n>` spec
  /// (null for the full/nightly lane).
  static BudgetTelemetry start({String? shard}) =>
      BudgetTelemetry._(startedAt: DateTime.now().toUtc(), shard: shard);

  /// The verdict schema tag.
  static const schema = 'corpus.budget.v1';

  final DateTime startedAt;
  final String? shard;

  final List<BudgetStepRecord> _steps = [];
  final List<MutantCounts> _stepsMutants = [];

  String? _result;
  int _features = 0;

  /// Record one per-feature step spawn (wall-clock + outcome).
  void recordStep({
    required String feature,
    required String step,
    required Duration elapsed,
    required String outcome,
  }) {
    _steps.add(
      BudgetStepRecord(
        feature: feature,
        step: step,
        elapsed: elapsed,
        outcome: outcome,
      ),
    );
  }

  /// Accumulate one verify step's parsed mutant counts (null — no
  /// machine line — contributes nothing; never fabricated zeros).
  void recordMutants(MutantCounts? counts) {
    if (counts == null) return;
    _stepsMutants.add(counts);
  }

  MutantCounts _aggregatedMutants() {
    var killed = 0;
    var survived = 0;
    var timedOut = 0;
    for (final c in _stepsMutants) {
      killed += c.killed;
      survived += c.survived;
      timedOut += c.timedOut;
    }
    return MutantCounts(killed: killed, survived: survived, timedOut: timedOut);
  }

  /// Stamp the lane's final result + driven feature count.
  void finish({required String result, required int features}) {
    _result = result;
    _features = features;
  }

  /// The verdict object (the JSON shape CI parses).
  Map<String, dynamic> toJson() {
    final finished = DateTime.now().toUtc();
    final suiteMs = _steps.fold<int>(
      0,
      (sum, s) => sum + s.elapsed.inMilliseconds,
    );
    final mutants = _aggregatedMutants();
    return {
      'schema': schema,
      'shard': shard,
      'started_at': startedAt.toIso8601String(),
      'finished_at': finished.toIso8601String(),
      'wall_clock_ms': finished.difference(startedAt).inMilliseconds,
      'features': _features,
      'result': _result,
      'steps': [for (final step in _steps) step.toJson()],
      'suite_seconds': (suiteMs / 1000).round(),
      'mutants': {
        'killed': mutants.killed,
        'survived': mutants.survived,
        'timed_out': mutants.timedOut,
      },
    };
  }

  /// Write the JSON verdict to [path] (pretty-printed, durable). The
  /// parent directory is created when missing. Returns [path].
  Future<String> write({required String path}) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
    return path;
  }

  /// Parse the mutant counts from a verify step's combined output —
  /// the LAST `mutation: gate=… killed=… survived=… timed_out=…`
  /// machine line (the verify command's final machine contract).
  /// Returns null when no parseable line exists (never fabricated).
  static MutantCounts? parseMutantCounts(String output) {
    MutantCounts? last;
    for (final line in output.split('\n')) {
      if (!line.startsWith('mutation: ')) continue;
      final fields = <String, String>{};
      for (final match in RegExp(
        r'(\w+)=([^\s]+)',
      ).allMatches(line.substring(9))) {
        fields[match.group(1)!] = match.group(2)!;
      }
      final killed = int.tryParse(fields['killed'] ?? '');
      final survived = int.tryParse(fields['survived'] ?? '');
      final timedOut = int.tryParse(fields['timed_out'] ?? '');
      if (killed == null || survived == null || timedOut == null) continue;
      last = MutantCounts(
        killed: killed,
        survived: survived,
        timedOut: timedOut,
      );
    }
    return last;
  }
}
