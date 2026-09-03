@Tags(['slow'])
// SC-023 (spec 071-inert-stub-red, A1/A7/U3): a certified red NAMES the
// failing authored assertion. The verdict surface grows:
//
//   - a `   red-evidence: <identity>` detail line on stdout,
//   - an `evidence=<identity>` token appended to the summary line,
//   - an optional `- evidence:` line in the cycle-log red entry.
//
// Rejection paths stay byte-identical to the pre-#959 contract: no
// evidence token on non-assertion classes (VISION §4 — the agent parses
// verdicts; unchanged lines never break consumers).
//
// The fixture root is passed via `--project`; the runner is a spy script
// emitting a canned finder-failure transcript (no Flutter execution).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const description = "renders the 'Home' label after sign-in";
  const identity = "B-001 \u2014 renders the 'Home' label after sign-in";

  final finderTranscript = '''
00:00 +0: loading test/b_001_test.dart
00:00 +0 -1: $identity [E]
  Expected: exactly one matching node in the widget tree
    Actual: _TextWidgetFinder:<zero widgets with text "Home">
   Which: none

00:00 +0 -1: Some tests failed.
''';

  setUp(() async {
    fx = await TddFixture.create(featureName: '071-inert-stub-red');
    final spy = await fx.writeSpyScript(
      'single-finder',
      output: finderTranscript,
      exit: '1',
    );
    await fx.rewriteProfile(
      singleTemplate: '$spy {file} "{name}"',
      suiteTemplate: 'dart test',
    );
    await fx.registerBehavior(id: 'B-001', description: description);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('A1/A7: certified red prints the red-evidence detail line', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'verify-red',
      '--project',
      fx.root.path,
      'B-001',
    ]);
    expect(
      out,
      contains('   red-evidence: $identity'),
      reason: 'the verdict must name the failing authored assertion',
    );
  });

  test('A7: certified red appends the evidence token to the summary line',
      () async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'verify-red',
      '--project',
      fx.root.path,
      'B-001',
    ]);
    final last = out.trim().split('\n').last;
    expect(
      last,
      'verify-red: behavior=B-001 classification=assertion certified=true '
      'feature=071-inert-stub-red evidence=$identity',
      reason: 'the evidence token is the LAST space-separated token; '
          'consumers parse tokens, never prose',
    );
  });

  test('A1: the cycle-log red entry carries the - evidence: field', () async {
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing([
      'tdd',
      'verify-red',
      '--project',
      fx.root.path,
      'B-001',
    ]);
    final log = File(fx.cycleLogPath).readAsStringSync();
    expect(log, contains('- kind: red'));
    expect(log, contains('- evidence: $identity'));
  });

  test('U3: rejection paths stay byte-identical — no evidence token', () async {
    final fx2 = await TddFixture.create(featureName: '071-inert-stub-red');
    try {
      final greenSpy = await fx2.writeSpyScript(
        'single-green',
        output: '00:00 +1: All tests passed!\n',
        exit: '0',
      );
      await fx2.rewriteProfile(
        singleTemplate: '$greenSpy {file} "{name}"',
        suiteTemplate: 'dart test',
      );
      await fx2.registerBehavior(
        id: 'B-001',
        description: description,
        testContent: TddFixture.greenTest(description),
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--project',
        fx2.root.path,
        'B-001',
      ]);
      final last = out.trim().split('\n').last;
      expect(
        last,
        'verify-red: behavior=B-001 classification=unexpected-green '
        'certified=false feature=071-inert-stub-red',
        reason: 'unexpected-green (the vacuous/scaffold refusal) keeps the '
            'pre-#959 line exactly — no evidence token',
      );
    } finally {
      fx2.dispose();
      exitCode = 0;
    }
  });
}
