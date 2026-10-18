import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/models/mutation_diff_report.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_diff.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_verifier.dart';

MutationResult _result({
  required int killed,
  required int survived,
  required int timedOut,
  List<MutationSurvivor> survivors = const [],
}) {
  return MutationResult(
    exitCode: survived > 0 ? 1 : 0,
    killedCount: killed,
    survivedCount: survived,
    timeoutCount: timedOut,
    elapsed: Duration.zero,
    reportPath: null,
    stdoutText: '',
    stderrText: '',
    survivors: survivors,
  );
}

void main() {
  group('MutationDiff', () {
    test('reports newly killed and missed mutants', () {
      final base = _result(
        killed: 5,
        survived: 2,
        timedOut: 0,
        survivors: [
          const MutationSurvivor(file: 'a.dart', line: 10),
          const MutationSurvivor(file: 'b.dart', line: 20),
        ],
      );
      final head = _result(
        killed: 17,
        survived: 1,
        timedOut: 0,
        survivors: [
          const MutationSurvivor(file: 'b.dart', line: 20),
          const MutationSurvivor(file: 'c.dart', line: 30),
        ],
      );
      final report = const MutationDiff().compute(
        base: base,
        head: head,
        threshold: 0.8,
      );
      expect(report.newKilled, 12);
      expect(report.newSurvivedMutants.length, 1);
      expect(report.newSurvivedMutants.first.toString(), 'c.dart:30');
      expect(report.newMutants, 13);
      expect(report.thresholdMet, isTrue);
      expect(report.gate, MutationDiffGate.pass);
    });

    test('fails gate when missed ratio exceeds threshold', () {
      final base = _result(killed: 0, survived: 0, timedOut: 0);
      final head = _result(
        killed: 1,
        survived: 9,
        timedOut: 0,
        survivors: [
          for (var i = 0; i < 9; i++)
            MutationSurvivor(file: 'x.dart', line: i + 1),
        ],
      );
      final report = const MutationDiff().compute(
        base: base,
        head: head,
        threshold: 0.8,
      );
      expect(report.newKilled, 1);
      expect(report.newSurvivedMutants.length, 9);
      expect(report.thresholdMet, isFalse);
      expect(report.gate, MutationDiffGate.failSurvived);
    });

    test('vacuously passes when no new mutants', () {
      final base = _result(killed: 5, survived: 1, timedOut: 0);
      final head = _result(killed: 5, survived: 1, timedOut: 0);
      final report = const MutationDiff().compute(base: base, head: head);
      expect(report.newMutants, 0);
      expect(report.thresholdMet, isTrue);
    });

    test('markdown and json contain the summary', () {
      final base = _result(killed: 0, survived: 0, timedOut: 0);
      final head = _result(
        killed: 2,
        survived: 1,
        timedOut: 0,
        survivors: [const MutationSurvivor(file: 'f.dart', line: 7)],
      );
      final report = const MutationDiff().compute(base: base, head: head);
      expect(
        report.toMarkdown(),
        contains('kills **2** new mutant(s), misses **1**'),
      );
      final json = report.toJson();
      expect(json, contains('"new_killed": 2'));
    });
  });
}
