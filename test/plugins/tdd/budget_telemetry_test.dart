/// Spec 069-corpus-economics, T003 — the budget telemetry contract:
/// every corpus-lane JSON verdict carries the measured budget —
/// wall-clock per step, suite seconds, mutant count (spec 069 FR-010,
/// issue #916).
library;

import 'dart:convert';

import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/services/budget_telemetry.dart';

void main() {
  test('the JSON verdict block carries the three budget axes', () {
    final telemetry = BudgetTelemetry();
    telemetry.wallClock.addDuration('run', const Duration(seconds: 2));
    telemetry.wallClock.addDuration('verify', const Duration(seconds: 1));
    telemetry.wallClock.addDuration('run', const Duration(seconds: 1));
    telemetry.addSuiteSeconds(2.6);
    telemetry.addMutants(8);

    final json = telemetry.toJson();
    expect(json['wall_clock_ms'], isA<Map<String, dynamic>>());
    expect(json['wall_clock_ms']['run'], 3000);
    expect(json['wall_clock_ms']['verify'], 1000);
    expect(json['wall_clock_ms']['total'], greaterThanOrEqualTo(0));
    expect(json['suite_seconds'], 3);
    expect(json['mutant_count'], 8);

    // The encoded block is valid indented JSON (the verdict file body).
    final decoded = jsonDecode(telemetry.encode()) as Map<String, dynamic>;
    expect(decoded['mutant_count'], 8);
  });

  test('accumulators are additive across features (shard lane merging)', () {
    final lane = BudgetTelemetry();
    lane.wallClock.addDuration('run', const Duration(milliseconds: 100));
    lane.addMutants(3);
    lane.addSuiteSeconds(1.2);

    final shard = BudgetTelemetry();
    shard.wallClock.addDuration('run', const Duration(milliseconds: 50));
    shard.wallClock.addDuration('verify', const Duration(milliseconds: 25));
    shard.addMutants(4);
    shard.addSuiteSeconds(0.8);

    lane.merge(shard);
    expect(lane.wallClock.millisOf('run'), 150);
    expect(lane.wallClock.millisOf('verify'), 25);
    expect(lane.mutantCount, 7);
    expect(lane.suiteSeconds, 2);
  });

  test('fromJson round-trips a persisted verdict block', () {
    final telemetry = BudgetTelemetry();
    telemetry.wallClock.addDuration('run', const Duration(seconds: 4));
    telemetry.addSuiteSeconds(1);
    telemetry.addMutants(12);

    final restored = BudgetTelemetry.fromJson(
      jsonDecode(telemetry.encode()) as Map<String, dynamic>,
    );
    expect(restored, isNotNull);
    expect(restored!.wallClock.millisOf('run'), 4000);
    expect(restored.suiteSeconds, 1);
    expect(restored.mutantCount, 12);
  });

  test('fromJson refuses a foreign block (null, never a crash)', () {
    expect(BudgetTelemetry.fromJson({'unrelated': true}), isNull);
    expect(
      BudgetTelemetry.fromJson({
        'wall_clock_ms': 'not-a-map',
        'suite_seconds': 1,
        'mutant_count': 1,
      }),
      isNull,
    );
  });

  test('stepNames is sorted (stable verdict field order)', () {
    final telemetry = BudgetTelemetry();
    telemetry.wallClock.addMillis('verify', 1);
    telemetry.wallClock.addMillis('run', 1);
    expect(telemetry.wallClock.stepNames, ['run', 'verify']);
  });
}
