// Spec 069-corpus-economics — T003: budget telemetry (part 2).
//
// The corpus lane's JSON verdicts must carry budget telemetry —
// wall-clock per step, suite seconds, mutant counts (issue #916's
// "budget telemetry (wall-clock per step, suite seconds, mutant count)
// in JSON verdicts") so CI can enforce the ≤ 30 min full / ≤ 10 min
// sharded budgets against REAL numbers. This file pins the telemetry
// contract:
//
//   1. Per-step records carry feature, step, wall-clock ms, and the
//      step's outcome.
//   2. suite_seconds aggregates the step wall-clocks (the lane's suite
//      work).
//   3. Mutant counts parse from the verify step's machine line
//      (`mutation: gate=… killed=1 survived=0 timed_out=0 …`).
//   4. The verdict JSON carries the schema tag, shard, wall clock, and
//      every budget field — parseable by CI.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/budget_telemetry.dart';

void main() {
  group('BudgetTelemetry — per-step wall clock', () {
    test('records per-step entries with feature, step, ms, and outcome', () {
      final telemetry = BudgetTelemetry.start(shard: '2/4');
      telemetry.recordStep(
        feature: 'f1',
        step: 'run',
        elapsed: const Duration(milliseconds: 1500),
        outcome: 'complete',
      );
      telemetry.recordStep(
        feature: 'f1',
        step: 'verify',
        elapsed: const Duration(milliseconds: 2500),
        outcome: 'pass',
      );

      final json = telemetry.toJson();
      expect(json['schema'], 'corpus.budget.v1');
      expect(json['shard'], '2/4');
      final steps = (json['steps'] as List).cast<Map<String, dynamic>>();
      expect(steps, hasLength(2));
      expect(steps[0]['feature'], 'f1');
      expect(steps[0]['step'], 'run');
      expect(steps[0]['wall_clock_ms'], 1500);
      expect(steps[0]['outcome'], 'complete');
      expect(steps[1]['step'], 'verify');
      expect(steps[1]['wall_clock_ms'], 2500);
    });

    test('suite_seconds aggregates every step\'s wall clock', () {
      final telemetry = BudgetTelemetry.start();
      telemetry.recordStep(
        feature: 'f1',
        step: 'run',
        elapsed: const Duration(seconds: 60),
        outcome: 'complete',
      );
      telemetry.recordStep(
        feature: 'f1',
        step: 'verify',
        elapsed: const Duration(seconds: 30),
        outcome: 'pass',
      );
      telemetry.recordStep(
        feature: 'f2',
        step: 'run',
        elapsed: const Duration(seconds: 45),
        outcome: 'complete',
      );

      expect(telemetry.toJson()['suite_seconds'], 135);
    });

    test(
      'wall_clock_ms is present, positive, and >= the recorded steps',
      () async {
        final telemetry = BudgetTelemetry.start();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        telemetry.recordStep(
          feature: 'f1',
          step: 'run',
          elapsed: const Duration(milliseconds: 5),
          outcome: 'complete',
        );
        final json = telemetry.toJson();
        expect(json['wall_clock_ms'] as int, greaterThanOrEqualTo(5));
        // started_at / finished_at carry ISO-8601 timestamps.
        expect(DateTime.tryParse(json['started_at'] as String), isNotNull);
        expect(DateTime.tryParse(json['finished_at'] as String), isNotNull);
      },
    );
  });

  group('BudgetTelemetry — mutant counts', () {
    test('parseMutantCounts reads the verify machine line', () {
      const output = '''
zfa tdd verify: running mutation audit...
   gate: pass
   killed: 12
   survived: 0
   timed_out: 1
mutation: gate=pass killed=12 survived=0 timed_out=1 mutation_was_run=true
''';
      final counts = BudgetTelemetry.parseMutantCounts(output);
      expect(counts, isNotNull);
      expect(counts!.killed, 12);
      expect(counts.survived, 0);
      expect(counts.timedOut, 1);
    });

    test('a missing machine line yields null (never fabricated zeros)', () {
      expect(BudgetTelemetry.parseMutantCounts('no lines here'), isNull);
      expect(BudgetTelemetry.parseMutantCounts('mutation: gate=pass'), isNull);
    });

    test('mutant totals accumulate across verify steps', () {
      final telemetry = BudgetTelemetry.start();
      telemetry.recordMutants(
        BudgetTelemetry.parseMutantCounts(
          'mutation: gate=pass killed=3 survived=0 timed_out=0',
        ),
      );
      telemetry.recordMutants(
        BudgetTelemetry.parseMutantCounts(
          'mutation: gate=pass killed=2 survived=1 timed_out=0',
        ),
      );
      final mutants = telemetry.toJson()['mutants'] as Map<String, dynamic>;
      expect(mutants['killed'], 5);
      expect(mutants['survived'], 1);
      expect(mutants['timed_out'], 0);
    });
  });

  group('BudgetTelemetry — the JSON verdict file', () {
    test('write() persists the verdict; the file round-trips parseable '
        'JSON with the budget fields', () async {
      final dir = await Directory.systemTemp.createTemp('budget_tel_');
      try {
        final path = dir.path;
        final telemetry = BudgetTelemetry.start(shard: '1/2');
        telemetry.recordStep(
          feature: 'f1',
          step: 'run',
          elapsed: const Duration(milliseconds: 900),
          outcome: 'complete',
        );
        telemetry.recordStep(
          feature: 'f1',
          step: 'verify',
          elapsed: const Duration(milliseconds: 100),
          outcome: 'pass',
        );
        telemetry.recordMutants(
          BudgetTelemetry.parseMutantCounts(
            'mutation: gate=pass killed=7 survived=0 timed_out=0',
          ),
        );
        telemetry.finish(result: 'complete', features: 1);

        final verdictPath = p.join(path, 'budget-telemetry.json');
        final file = await telemetry.write(path: verdictPath);
        expect(file, verdictPath);
        final decoded =
            jsonDecode(await File(verdictPath).readAsString())
                as Map<String, dynamic>;
        expect(decoded['schema'], 'corpus.budget.v1');
        expect(decoded['shard'], '1/2');
        expect(decoded['result'], 'complete');
        expect(decoded['features'], 1);
        expect(decoded['suite_seconds'], 1);
        expect((decoded['mutants'] as Map<String, dynamic>)['killed'], 7);
        expect((decoded['steps'] as List), hasLength(2));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('the same step seconds parse back from the file (CI-side budget '
        'check)', () async {
      final dir = await Directory.systemTemp.createTemp('budget_tel2_');
      try {
        final telemetry = BudgetTelemetry.start();
        telemetry.recordStep(
          feature: 'f1',
          step: 'run',
          elapsed: const Duration(milliseconds: 3000),
          outcome: 'complete',
        );
        telemetry.finish(result: 'incomplete', features: 0);
        final file = await telemetry.write(path: '${dir.path}/t.json');
        final decoded =
            jsonDecode(await File(file).readAsString()) as Map<String, dynamic>;
        final steps = (decoded['steps'] as List).cast<Map<String, dynamic>>();
        final suiteSeconds = (decoded['suite_seconds'] as num).toDouble();
        expect(suiteSeconds, 3);
        expect(steps.first['wall_clock_ms'], 3000);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}
