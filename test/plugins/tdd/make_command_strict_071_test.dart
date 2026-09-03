@Tags(['slow'])
// A4/T028 (feature 071): `zfa tdd make --strict-routing` refuses an
// undeclared behavior with the fix-naming message — the composition
// fallback (a legacy fallback lane) must NOT engage, and the pipeline
// is never invoked. Issue #951; spec FR-010.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

List<String> makeArgs(TddFixture fx, {required String zfaBin}) => [
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--feature',
      fx.featureName,
      '--zfa-bin',
      zfaBin,
      '--strict-routing',
    ];

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('an undeclared unit make refuses under strict — no func surface, '
      'no generation, fix hint names the declaration', () async {
    const description = 'returns 42 when invoked with no args';
    await fx.seedTestList([
      (
        id: 'U-100',
        description: description,
        traces: 'FR-071',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.seedCertifiedRed(id: 'U-100', description: description);
    final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(
      makeArgs(fx, zfaBin: zfaBin),
    );

    expect(exitCode, 1);
    expect(out, contains('outcome=unexpressible'));
    expect(out, contains('--> fix:'));
    expect(out, contains('**Type**'));
    // The legacy fallback lanes never engaged: no view generation, no
    // composition, no pipeline invocation at all.
    final log = await fx.readFakeZfaLog();
    expect(log, isEmpty, reason: 'strict refuses BEFORE any generation');
    expect(out, isNot(contains('tdd func')));
  });
}
