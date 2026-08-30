// SC-001 acceptance test (spec 046-tdd-verify-red, US1.AC1-AC3 / T021):
// an honestly-red behavior certifies end to end through the real CLI —
// classification `assertion`, red entry appended, exit 0, and zero
// writes under test/ or lib/.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  late Directory prev;
  const description = 'returns 42 when invoked with no args';

  setUp(() async {
    prev = Directory.current;
    fx = await TddFixture.create(featureName: '046-tdd-verify-red');
    await fx.registerBehavior(
      id: 'B-001',
      description: description,
      sourceCriterion: 'FR-004',
    );
    Directory.current = fx.root;
  });

  tearDown(() {
    Directory.current = prev;
    fx.dispose();
    exitCode = 0;
  });

  test(
    'A1: honestly-red behavior certifies with classification assertion',
    () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['tdd', 'verify-red', 'B-001']);

      expect(
        out,
        contains(
          'verify-red: behavior=B-001 classification=assertion '
          'certified=true feature=046-tdd-verify-red',
        ),
      );
      expect(exitCode, 0);
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('## Cycle: B-001 (red)'));
      expect(log, contains('- classification: assertionFailure'));
    },
  );

  test(
    'A2: the appended red entry carries all 8 contract fields',
    () async {
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(['tdd', 'verify-red', 'B-001']);
      final log = await File(fx.cycleLogPath).readAsString();

      final orderedFields = [
        '- behavior: B-001',
        '- kind: red',
        '- classification: assertionFailure',
        '- criterion: FR-004',
        '- test: ${fx.testPathOf('B-001')}',
        '- exit: 1',
      ];
      var last = -1;
      for (final line in orderedFields) {
        final idx = log.indexOf(line);
        expect(idx, greaterThan(last), reason: 'missing or out of order: $line');
        last = idx;
      }
      // command, at, and output blocks present too.
      expect(log, contains('- command: `dart test'));
      expect(RegExp(r'^- at: \S+$', multiLine: true).hasMatch(log), isTrue);
      expect(log, contains('- output:'));
    },
  );

  test('A3: a certified run modifies no file under test/ or lib/', () async {
    final before = fx.checksumTestAndLib();
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing(['tdd', 'verify-red', 'B-001']);
    expect(fx.checksumTestAndLib(), equals(before));
  });
}
