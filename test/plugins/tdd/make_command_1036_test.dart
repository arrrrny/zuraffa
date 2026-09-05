// Tests for bug #1036 — the acceptance-lane make pipeline rewrote the
// throwing subject stub to a non-throwing func scaffold BEFORE the
// generation step that would fill it, and the #694 skip transition then
// certified green on the vacuous placeholder: the red evidence proved an
// assertion failure the green evidence no longer exercised.
//
// Contract under test (issue #1036):
//   1. A FAILED make leaves the subject file byte-identical to what it
//      found — the throwing stub survives a generation-error untouched,
//      so the retry fails honestly instead of skipping green on a
//      placeholder.
//   2. The skip transition validates the subject under test is the SAME
//      shape the certified evidence captured: verify-red records the
//      subject hash (`- subject-hash:`), make records it on green, and a
//      skip whose subject hash drifted since the last certified entry is
//      refused (exit non-zero, `--> fix:` line, no green evidence).
//   3. Unit behaviors' skip semantics are UNCHANGED: a make re-run after
//      an honest certified green still skips (exit 0, outcome=skipped,
//      green evidence appended) because the subject hash matches the
//      certified green evidence.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

List<String> makeArgs1036(TddFixture fx, {String? id, String? zfaBin}) {
  final args = <String>['tdd', 'make', '--project', fx.root.path];
  if (zfaBin != null) args.addAll(['--zfa-bin', zfaBin]);
  if (id != null) args.add(id);
  return args;
}

List<String> verifyRedArgs1036(TddFixture fx, {String? id}) {
  final args = <String>['tdd', 'verify-red', '--project', fx.root.path];
  if (id != null) args.add(id);
  return args;
}

/// The gen-shaped THROWING acceptance subject stub (`zfa tdd gen A1`).
String throwingSubject(String id) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  return '''
// GENERATED STUB — `zfa tdd gen $id`.
library;

/// Scenario runner for behavior $id.
///
/// Throws [UnimplementedError] until the real implementation lands.
void $symbol() => throw UnimplementedError('$symbol not implemented');
''';
}

/// The non-throwing func scaffold the make pipeline rewrote the stub to
/// (the #1036 placeholder: `String subject_a1() { return 'subject_a1'; }`).
String funcScaffoldSubject(String id) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  return '''
library;

String $symbol() {
  return '$symbol';
}
''';
}

/// The born-green vacuous acceptance test (#1036's red surface): it fails
/// ONLY when the subject throws — any non-throwing placeholder body
/// passes it, so a green on the placeholder proves nothing about the
/// scenario.
String vacuousAcceptanceTest(String id, String description) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  return '''
import '../lib/${symbol}_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    // The born-green vacuity of #1036: this assertion fails ONLY when
    // the subject throws — any non-throwing placeholder body passes.
    expect($symbol, isNot(throwsA(isA<UnimplementedError>())));
  });
}
''';
}

/// A test that FAILS against the func scaffold too (it asserts the
/// scenario's actual result) — used for the post-generation
/// target-still-fails failure path.
String scenarioAssertionTest(String id, String description) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  return '''
import '../lib/${symbol}_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect($symbol(), equals('SCENARIO-CONTRACT-VALUE'));
  });
}
''';
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('bug 1036: a failed make preserves the certified-red subject', () {
    test('A-1036a: generation-error after the func rewrite restores the '
        'throwing subject — the retry fails honestly', () async {
      const desc = 'render returns a non-empty string for a populated task';
      await fx.seedCertifiedRed(
        id: 'A1',
        description: desc,
        testContent: vacuousAcceptanceTest('A1', desc),
        subjectContent: throwingSubject('A1'),
      );
      final subjectPath = fx.subjectPathOf('A1');
      final before = await File(subjectPath).readAsString();
      expect(before, contains('throw UnimplementedError'));

      // The plan for A1 is the func surface: `tdd func A1` (rewrites the
      // throwing stub into the non-throwing scaffold) then `build` —
      // which FAILS with analyzer errors (the bug's "generation-error",
      // composition unavailable): the #942 gate refuses the tolerance,
      // and pre-fix the placeholder survived the failed make.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'A1',
            funcScaffoldSubject('A1'),
          ),
        },
        exitByArgv: {'build': 1},
        stdoutByArgv: {
          'build': [
            'error - Composition unavailable: the acceptance subject '
                'cannot be composed (issue #1036 repro).',
          ],
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs1036(fx, id: 'A1', zfaBin: zfaBin),
      );
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('generation-error'));

      // THE FIX: the subject on disk is byte-identical to the certified-
      // red throwing stub — a failed make leaves no subject mutation.
      final after = await File(subjectPath).readAsString();
      expect(
        after,
        equals(before),
        reason:
            'a failed make must preserve the throwing subject so the '
            'retry fails honestly (issue #1036)',
      );
      expect(after, contains('throw UnimplementedError'));

      // No green evidence was appended.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, isNot(contains('## Cycle: A1 (green)')));
    });

    test('A-1036b: post-generation target-still-fails also restores the '
        'throwing subject', () async {
      const desc = 'render returns a non-empty string for a populated task';
      // The test asserts the SCENARIO result: it fails against the
      // throwing stub AND against the func scaffold.
      await fx.seedCertifiedRed(
        id: 'A2',
        description: desc,
        testContent: scenarioAssertionTest('A2', desc),
        subjectContent: throwingSubject('A2'),
      );
      final subjectPath = fx.subjectPathOf('A2');
      final before = await File(subjectPath).readAsString();

      // `tdd func` rewrites the stub; `build` SUCCEEDS; the post-
      // generation target run still fails → generation-error.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'A2',
            funcScaffoldSubject('A2'),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs1036(fx, id: 'A2', zfaBin: zfaBin),
      );
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('generation-error'));

      final after = await File(subjectPath).readAsString();
      expect(after, equals(before), reason: 'issue #1036');
    });
  });

  group('bug 1036: the skip transition validates the subject hash', () {
    test(
      'A-1036c: verify-red records the subject hash in the red entry',
      () async {
        const desc = 'render returns a non-empty string for a populated task';
        await fx.seedCertifiedRed(
          id: 'A3',
          description: desc,
          testContent: vacuousAcceptanceTest('A3', desc),
          subjectContent: throwingSubject('A3'),
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(verifyRedArgs1036(fx, id: 'A3'));
        expect(exitCode, 0, reason: out);

        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(cycleLog, contains('## Cycle: A3 (red)'));
        expect(cycleLog, contains('- subject-hash: '));
      },
    );

    test('A-1036d: a skip whose subject drifted since the certified red is '
        'refused — no green evidence, --> fix: line', () async {
      const desc = 'render returns a non-empty string for a populated task';
      await fx.seedCertifiedRed(
        id: 'A4',
        description: desc,
        testContent: vacuousAcceptanceTest('A4', desc),
        subjectContent: throwingSubject('A4'),
      );

      // Certify red against the THROWING subject (records its hash).
      final runner = CliRunner(exitOnCompletion: false);
      final redOut = await runner.runCapturing(verifyRedArgs1036(fx, id: 'A4'));
      expect(exitCode, 0, reason: redOut);

      // The failed-make rewrite class: the subject on disk is now the
      // non-throwing placeholder the red evidence never exercised.
      await File(
        fx.subjectPathOf('A4'),
      ).writeAsString(funcScaffoldSubject('A4'));

      // The retry make: the drift check passes (the vacuous test passes
      // on the placeholder) — the skip transition MUST refuse.
      final out = await runner.runCapturing(makeArgs1036(fx, id: 'A4'));
      expect(
        exitCode,
        isNot(0),
        reason:
            'a skip on a subject whose shape no longer matches the '
            'certified red evidence must be refused (issue #1036): $out',
      );
      expect(out, contains('--> fix:'));
      expect(out, contains('subject'));

      // NO green evidence was appended — the born-green certification is
      // the exact dishonesty #1036 forbids.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, isNot(contains('## Cycle: A4 (green)')));

      // The drifted subject is left untouched (the refusal never
      // rewrites the subject).
      expect(
        await File(fx.subjectPathOf('A4')).readAsString(),
        equals(funcScaffoldSubject('A4')),
      );
    });
  });

  group('bug 1036: unit skip semantics are preserved', () {
    test('U-1036e: a make re-run after an honest certified green still '
        'skips (exit 0, outcome=skipped, green evidence)', () async {
      const desc = 'compute returns 42 when invoked with no args';
      await fx.seedCertifiedRed(
        id: 'U1',
        description: desc,
        testContent: TddFixture.subjectDrivenTest('U1', desc),
      );

      // Honest make: the func step writes the production subject (the
      // described contract), build passes, green is certified.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U1',
            TddFixture.subjectReturning('U1', 42),
          ),
        },
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs1036(fx, id: 'U1', zfaBin: zfaBin),
      );
      expect(exitCode, 0, reason: out);
      expect(out, contains('make: behavior=U1 outcome=green'));

      // The green entry records the subject hash of the scaffolded
      // subject.
      var cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: U1 (green)'));
      expect(cycleLog, contains('- subject-hash: '));

      // The #694 re-run: drift check passes, subject unchanged since the
      // certified green → skip transition proceeds EXACTLY as before.
      final out2 = await runner.runCapturing(
        makeArgs1036(fx, id: 'U1', zfaBin: zfaBin),
      );
      expect(exitCode, 0, reason: out2);
      expect(out2, contains('outcome=skipped'));
      cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: U1 (green)'));
    });
  });
}
