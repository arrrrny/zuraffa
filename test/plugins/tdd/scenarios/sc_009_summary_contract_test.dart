@Tags(['slow'])
// Acceptance scenario sc_009: summary-line + exit-code contract
// (spec 047-tdd-make, US5.AC1 / US5.AC2).
//
// Verifies the contract that `zfa tdd run` and CI can consume without
// parsing prose:
//   A13: every invocation ends with the summary line in the pinned
//        format `make: behavior=<id> outcome=<outcome> feature=<f>`.
//   A14: exit code 0 occurs exactly on `green`; every rejection and
//        misfire is non-zero.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

const _sc009Description = 'create entity User with email';
const _sc009GreenTest =
    '''
import 'package:test/test.dart';

void main() {
  test('$_sc009Description', () {
    expect(1, equals(1));
  });
}
''';

void main() {
  late TddFixture fx;

  final shape = RegExp(r'^make: behavior=(\S+) outcome=(\S+) feature=(\S+)$');

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('A13 — every invocation ends with the summary line in the pinned '
      'format across outcome classes', () async {
    await fx.seedCertifiedRed(id: 'B-001', description: _sc009Description);
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      sideEffectByArgv: {
        'entity create': [
          'cat > "${fx.testPathOf('B-001')}" <<\'ZFA_EOF\'',
          _sc009GreenTest,
          'ZFA_EOF',
        ],
      },
    );

    final runner = CliRunner(exitOnCompletion: false);

    // Green path.
    final green = await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-001',
    ]);
    final greenLine = green.trim().split('\n').last;
    final m1 = shape.firstMatch(greenLine);
    expect(m1, isNotNull, reason: 'line: "$greenLine"');
    expect(m1!.group(1), 'B-001');
    expect(m1.group(2), 'green');
    expect(m1.group(3), fx.featureName);
    expect(exitCode, 0);
    exitCode = 0;

    // Unknown id.
    final unknown = await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-404',
    ]);
    final unknownLine = unknown.trim().split('\n').last;
    final m2 = shape.firstMatch(unknownLine);
    expect(m2, isNotNull, reason: 'line: "$unknownLine"');
    expect(m2!.group(2), 'runner-error');
    expect(exitCode, isNot(0));
    exitCode = 0;

    // Unexpressible.
    await fx.seedCertifiedRed(
      id: 'B-042',
      description: 'parse bespoke DSL syntax with no generator surface',
    );
    final unexpr = await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-042',
    ]);
    final unexprLine = unexpr.trim().split('\n').last;
    final m3 = shape.firstMatch(unexprLine);
    expect(m3, isNotNull, reason: 'line: "$unexprLine"');
    expect(m3!.group(2), 'unexpressible');
    expect(exitCode, isNot(0));
    exitCode = 0;

    // Generation-error.
    await fx.seedCertifiedRed(id: 'B-002', description: _sc009Description);
    final failingZfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      exitByArgv: {'entity create': 1},
    );
    final genErr = await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      failingZfaBin,
      'B-002',
    ]);
    final genErrLine = genErr.trim().split('\n').last;
    final m4 = shape.firstMatch(genErrLine);
    expect(m4, isNotNull, reason: 'line: "$genErrLine"');
    expect(m4!.group(2), 'generation-error');
    expect(exitCode, isNot(0));
    exitCode = 0;
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('A14 — exit code 0 occurs EXACTLY on `green`; every rejection and '
      'misfire is non-zero', () async {
    await fx.seedCertifiedRed(id: 'B-001', description: _sc009Description);
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      sideEffectByArgv: {
        'entity create': [
          'cat > "${fx.testPathOf('B-001')}" <<\'ZFA_EOF\'',
          _sc009GreenTest,
          'ZFA_EOF',
        ],
      },
    );

    final runner = CliRunner(exitOnCompletion: false);

    // Green → 0.
    await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-001',
    ]);
    expect(exitCode, 0);
    exitCode = 0;

    // Unknown → non-zero.
    await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-404',
    ]);
    expect(exitCode, isNot(0));
    exitCode = 0;

    // Unexpressible → non-zero.
    await fx.seedCertifiedRed(
      id: 'B-042',
      description: 'parse bespoke DSL with no generator',
    );
    await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
      'B-042',
    ]);
    expect(exitCode, isNot(0));
    exitCode = 0;
  }, timeout: const Timeout(Duration(minutes: 5)));
}
