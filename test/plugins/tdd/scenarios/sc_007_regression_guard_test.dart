@Tags(['slow'])
// Acceptance scenario sc_007: regression guard via the full suite
// (spec 047-tdd-make, US3.AC1 / US3.AC2 / US3.AC3).
//
// Three regression-guard cases:
//   A7: clean guard → green entry records both target-test pass and
//       full-suite pass.
//   A8: sibling regression → exit non-zero naming the regressed test,
//       no green entry, source left in place.
//   A9: pre-existing suite failures tolerated; only NEW failures fail
//       the guard.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

const _description = 'create entity User with email';
const _greenTest =
    '''
import 'package:test/test.dart';

void main() {
  test('$_description', () {
    expect(1, equals(1));
  });
}
''';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('A7 — clean guard → green entry records both target-test pass and '
      'full-suite pass', () async {
    await fx.seedCertifiedRed(
      id: 'B-001',
      description: _description,
      testContent: TddFixture.subjectDrivenTest('B-001', _description),
    );
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      sideEffectByArgv: {
        'entity create': fx.overwriteSubjectCommands(
          'B-001',
          TddFixture.subjectReturning('B-001', 42),
        ),
      },
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-001',
    ]);

    expect(exitCode, 0, reason: 'out:\n$out');
    final log = await File(fx.cycleLogPath).readAsString();
    // Both target-test and suite captured.
    expect(log, contains('- command: `dart test'));
    expect(log, contains('- exit: 0'));
    expect(log, contains('- suite: baseline='));
    expect(log, contains('guard='));
    expect(log, contains('new=(none)'));
  });

  test('A8 — sibling regression → exit non-zero naming the regressed test, '
      'no green entry, source left in place', () async {
    await fx.seedCertifiedRed(
      id: 'B-001',
      description: _description,
      testContent: TddFixture.subjectDrivenTest('B-001', _description),
    );
    // Pre-existing GREEN sibling the fake pipeline will break.
    await fx.seedSiblingGreenTest(
      id: 'B-SIB',
      description: 'sibling green test passes',
    );

    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      sideEffectByArgv: {
        'entity create': [
          ...fx.overwriteSubjectCommands(
            'B-001',
            TddFixture.subjectReturning('B-001', 42),
          ),
          ...fx.overwriteSubjectCommands(
            'B-SIB',
            TddFixture.subjectReturning('B-SIB', 2),
          ),
        ],
      },
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-001',
    ]);

    expect(exitCode, isNot(0));
    expect(out, contains('regression'));
    expect(out, contains('sibling green test passes'));
    expect(
      out,
      contains(
        'make: behavior=B-001 outcome=regression feature=${fx.featureName}',
      ),
    );
    // No green entry appended (SC-003).
    final log = await File(fx.cycleLogPath).readAsString();
    expect(log, isNot(contains('## Cycle: B-001 (green)')));
    // Generated source left in place for inspection (NOT reverted).
    final siblingSource = await File(fx.subjectPathOf('B-SIB')).readAsString();
    expect(siblingSource, contains('=> 2'));
  });

  test('A9 — pre-existing suite failures tolerated; only NEW failures fail '
      'the guard', () async {
    await fx.seedCertifiedRed(id: 'B-001', description: _description);
    // Pre-existing BROKEN sibling — must be tolerated per US3.AC3.
    await fx.registerBehavior(
      id: 'B-SIB',
      description: 'pre-existing broken sibling',
      testContent: '''
import 'package:test/test.dart';

void main() {
  test('pre-existing broken sibling', () {
    expect(1, equals(2));
  });
}
''',
    );

    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      sideEffectByArgv: {
        'entity create': [
          'cat > "${fx.testPathOf('B-001')}" <<\'ZFA_EOF\'',
          _greenTest,
          'ZFA_EOF',
        ],
      },
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-001',
    ]);

    expect(exitCode, 0, reason: 'pre-existing failure tolerated; out:\n$out');
    expect(out, contains('outcome=green'));
    final log = await File(fx.cycleLogPath).readAsString();
    expect(log, contains('- suite: baseline='));
    expect(log, contains('guard='));
  });
}
