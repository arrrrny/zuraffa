import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

Future<List<String>> _capturePrints(Future<void> Function() body) async {
  final prints = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, __, ___, String message) {
        prints.add(message);
      },
    ),
  );
  return prints;
}

void main() {
  group('ProgressReporter', () {
    test('NullProgressReporter ignores all reports', () {
      final reporter = NullProgressReporter();
      expect(() => reporter.started('test', 5), returnsNormally);
      expect(() => reporter.update('step'), returnsNormally);
      expect(() => reporter.completed(), returnsNormally);
      expect(() => reporter.failed('error'), returnsNormally);
    });

    test('CliProgressReporter formats started message', () async {
      final prints = await _capturePrints(() async {
        final reporter = CliProgressReporter(verbose: true);
        reporter.started('Generating', 2);
        reporter.update('Step 1');
        reporter.completed();
      });

      expect(prints.first, equals('[_] Generating'));
      expect(
        prints.where((line) => line.contains('→ Step 1')).isNotEmpty,
        isTrue,
      );
      expect(
        prints.where((line) => line == '[✓] Completed').isNotEmpty,
        isTrue,
      );
    });

    test('ProgressReport calculates percentages correctly', () {
      final report = ProgressReport.started('Test', 4);
      final step1 = report.nextStep('one');
      final step2 = step1.nextStep('two');
      expect(step1.percent, equals(25));
      expect(step2.percent, equals(50));
    });
  });
}
