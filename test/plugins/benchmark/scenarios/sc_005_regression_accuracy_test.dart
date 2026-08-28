// Success criterion SC-005 (specs/015-benchmark-plugin/spec.md):
// regression detection accuracy — false positive rate < 5%, false negative
// rate < 1% for synthetic regression tests.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/baseline_store.dart';

void main() {
  test('accuracy within bounds', () {
    // Deterministic pseudo-random generator (no flakiness).
    var seed = 42;
    int next() => (seed = (seed * 1103515245 + 12345) & 0x7fffffff);

    const tolerance = 10.0;
    const totalCases = 200;
    const trueRegressions = 100;

    var falsePositives = 0; // flagged, but not truly regressed
    var falseNegatives = 0; // truly regressed, but not flagged
    var considered = 0;

    for (var i = 0; i < totalCases; i++) {
      final isTrueRegression = i < trueRegressions;
      final baselineValue = 100.0 + (next() % 1000) / 10;

      // Non-regressions stay at least 0.5% inside the tolerance band;
      // regressions land at least 0.5% beyond it.
      final double currentValue;
      if (isTrueRegression) {
        final overshoot = 0.5 + (next() % 4000) / 100; // +0.5% .. +40.5%
        currentValue = baselineValue * (1 + (tolerance + overshoot) / 100);
      } else {
        final undershoot = 0.5 + (next() % 1900) / 100; // up to 19.5% inside
        final direction = next() % 2 == 0 ? -1 : 1;
        final change = (tolerance - undershoot) / 100 * direction;
        currentValue = baselineValue * (1 + change);
      }

      final baseline = Baseline(
        scenarioId: 'accuracy-case-$i',
        scenarioVersion: '1.0.0',
        label: 'base',
        metrics: {'latency_p99': baselineValue},
        timestamp: DateTime.utc(2026, 8, 1),
      );

      final comparison = compareBaselines(
        baseline,
        {'latency_p99': currentValue},
        tolerancePercent: tolerance,
      );
      final flagged =
          comparison.changes['latency_p99']!.isRegression;

      considered++;
      if (flagged && !isTrueRegression) falsePositives++;
      if (!flagged && isTrueRegression) falseNegatives++;
    }

    expect(considered, totalCases);
    final fpRate = falsePositives / (totalCases - trueRegressions);
    final fnRate = falseNegatives / trueRegressions;

    expect(fpRate, lessThan(0.05),
        reason: 'false positive rate was ${(fpRate * 100).toStringAsFixed(1)}%');
    expect(fnRate, lessThan(0.01),
        reason: 'false negative rate was ${(fnRate * 100).toStringAsFixed(1)}%');
  });
}
