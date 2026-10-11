@Tags(['slow'])
// Issue #1323 — the non-scalar param hand-delta seam (make + writer).
//
// A declared contract param the writer cannot scalar-literalize emits an
// `_argN()` placeholder helper; when make's generation plan leaves the
// target test still failing on that placeholder, make dead-ends in the
// generic `generation-error` whose stop output never names the remedy.
// Spec 991 pins the remediation:
//
//   U-1323-1 — make detects the `_argN()` placeholder (test-file marker +
//              transcript token) and stops `hand-delta-required` naming
//              the EXACT edit; no green evidence (AC-1 / SC-1).
//   U-1323-2 — an unrelated red keeps the honest generic
//              `generation-error` (FR-001 precision).
//   U-1323-3 — `_scalarLiteral` covers `Object`: gen for
//              `reason(Object error) -> String` emits `Object()` at the
//              capture site and NO `_arg` helper (AC-3 / SC-3, the
//              preferred path).
//   U-1323-4 — the scalar literals are byte-unchanged
//              (AC-4 / SC-4, backward compatibility).
//   U-1323-5 — re-certification after the hand-edit: re-running make
//              re-runs the UPDATED test (drift check); a red re-cert
//              proceeds to generation and lands green; a green re-cert
//              takes the skip transition (AC-2 / SC-2, FR-005).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// The generated-test shape the writer emits today for a non-scalar
/// declared param (the issue's repro: `reason(Object error) -> String`,
/// `_arg0()` placeholder, typed outcome assertion).
const arg0Test = '''
import 'package:test/test.dart';
import '../lib/u6_subject.dart' as subject;

void main() {
  group('U6 (FR-1)', () {
    test('U6 — reason reports the error class', () {
      Object _arg0() => throw UnimplementedError('provide a representative argument for subject_u6 (declared param 0: Object)');
      final result = (() {
        try {
          return subject.reason(_arg0());
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isA<String>());
    });
  });
}
''';

/// The stub subject the red phase pairs with [arg0Test].
const throwingSubject = '''
library;

String reason(Object error) => throw UnimplementedError('stub');
''';

/// The real implementation the fake pipeline "generates" for the
/// re-certification cycle (U-1323-5): the hand-edited representative
/// argument flows through and the outcome asserts.
const realSubject = '''
library;

String reason(Object error) => 'handled: ' + error.runtimeType.toString();
''';

/// The hand-edited test (U-1323-5 red re-cert): `_arg0()` replaced with a
/// representative `Object` — the capture no longer swallows a placeholder
/// throw, the stub's own UnimplementedError keeps the red honest.
const handEditedRedTest = '''
import 'package:test/test.dart';
import '../lib/u6_subject.dart' as subject;

void main() {
  group('U6 (FR-1)', () {
    test('U6 — reason reports the error class', () {
      final result = (() {
        try {
          return subject.reason(StateError('boom'));
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isA<String>());
    });
  });
}
''';

/// The hand-edited test that PASSES against the stub (U-1323-5 green
/// re-cert probe): the drift check re-runs the updated test, certifies
/// green from it, and make takes the skip transition — proof the
/// certified-red entry never short-circuits the re-verification.
const handEditedGreenTest = '''
import 'package:test/test.dart';
import '../lib/u6_subject.dart' as subject;

void main() {
  group('U6 (FR-1)', () {
    test('U6 — reason reports the error class', () {
      final result = (() {
        try {
          return subject.reason(StateError('boom'));
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(true, isTrue);
    });
  });
}
''';

Future<String> runMake(TddFixture fx, String zfaBin, {String id = 'U6'}) =>
    CliRunner(exitOnCompletion: false).runCapturing([
      'tdd',
      'make',
      id,
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
    ]);

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create(featureName: '1323-hand-delta');
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('issue #1323 — make surfaces the hand-delta seam', () {
    test('U-1323-1: a still-failing _arg0() placeholder stop is '
        'hand-delta-required naming the exact edit', () async {
      const description = 'reason reports the error class';
      await fx.seedCertifiedRed(
        id: 'U6',
        description: description,
        testContent: arg0Test,
        subjectContent: throwingSubject,
      );
      // The generation "succeeds" but leaves the placeholder red: the
      // fake pipeline completes with no remedying side effect.
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final out = await runMake(fx, zfaBin);

      expect(
        exitCode,
        1,
        reason:
            'the placeholder red must not certify: '
            '$out',
      );
      expect(
        out,
        contains('outcome=hand-delta-required'),
        reason:
            'the designed seam is named, not the generic '
            'generation-error: $out',
      );
      expect(out, isNot(contains('outcome=generation-error')), reason: out);
      // The EXACT edit (AC-1): placeholder, test path, declared type,
      // re-run command.
      expect(out, contains('replace _arg0()'), reason: out);
      expect(out, contains('test/u6_test.dart'), reason: out);
      expect(out, contains('representative Object'), reason: out);
      expect(out, contains('then re-run zfa tdd make U6'), reason: out);
      // The failed-make contract holds: no green evidence appended.
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, isNot(contains('## Cycle: U6 (green)')), reason: log);
      // The subject survives byte-identically (issue #1036).
      expect(File(fx.subjectPathOf('U6')).readAsStringSync(), throwingSubject);
    });

    test('U-1323-2: an unrelated red keeps the honest generic '
        'generation-error', () async {
      const description = 'reason reports the error class';
      await fx.seedCertifiedRed(
        id: 'U6',
        description: description,
        subjectContent: throwingSubject,
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final out = await runMake(fx, zfaBin);

      expect(exitCode, 1, reason: out);
      expect(
        out,
        contains('outcome=generation-error'),
        reason:
            'no placeholder marker in the test — the generic stop '
            'stands: $out',
      );
      expect(out, isNot(contains('outcome=hand-delta-required')), reason: out);
      expect(out, isNot(contains('replace _arg0()')), reason: out);
    });

    test('U-1323-3: gen covers Object — `reason(Object error) -> String` '
        'emits Object() and no _arg helper', () async {
      await fx.seedTestList([
        (
          id: 'U-1323',
          description: 'reason reports the error class',
          traces: 'StreamErrorHandler.reason',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await Directory(fx.featureDir).create(recursive: true);
      await File(p.join(fx.featureDir, 'spec.md')).writeAsString('''
# Error Handling

### Layer Contracts

**Function**:
- `StreamErrorHandler`: `reason(Object error) -> String`
''');

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'gen', 'U-1323', '--project', fx.root.path]);

      expect(exitCode, 0, reason: 'out: $out');
      final generated = await fx.registryRecordOf('U-1323');
      final generatedTest = await File(
        generated['test_path'] as String,
      ).readAsString();
      expect(
        generatedTest,
        contains('(Object())'),
        reason:
            'the common Object case never dead-ends into the seam: '
            '$generatedTest',
      );
      expect(
        generatedTest,
        isNot(contains('_arg0()')),
        reason:
            'no placeholder helper for an Object-typed param: '
            '$generatedTest',
      );
      expect(
        generatedTest,
        isNot(contains('provide a representative argument')),
        reason: generatedTest,
      );
    });

    test('U-1323-4: the scalar literals are unchanged — String, int, num, '
        'bool, double keep their representative values', () async {
      await fx.seedTestList([
        (
          id: 'U-1324',
          description: 'formats the scalar sample',
          traces: 'Formatter.describe',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await Directory(fx.featureDir).create(recursive: true);
      await File(p.join(fx.featureDir, 'spec.md')).writeAsString('''
# Formatter

### Layer Contracts

**Function**:
- `Formatter`: `describe(String text, int count, num ratio, bool flag, double amount) -> String`
''');

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'gen', 'U-1324', '--project', fx.root.path]);

      expect(exitCode, 0, reason: 'out: $out');
      final generated = await fx.registryRecordOf('U-1324');
      final generatedTest = await File(
        generated['test_path'] as String,
      ).readAsString();
      expect(
        generatedTest,
        contains("(r'sample', 0, 0, false, 0.0)"),
        reason: 'the scalar representatives are verbatim: $generatedTest',
      );
      expect(
        generatedTest,
        isNot(contains('_arg')),
        reason: 'scalar params never take the seam: $generatedTest',
      );
    });
  });

  group('issue #1323 — re-certification after the hand-edit (AC-2)', () {
    test('U-1323-5: re-running make re-runs the UPDATED test — a red '
        're-cert proceeds to generation and lands green', () async {
      const description = 'reason reports the error class';
      await fx.seedCertifiedRed(
        id: 'U6',
        description: description,
        testContent: arg0Test,
        subjectContent: throwingSubject,
      );
      final zfaBin1 = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      // Cycle 1: the placeholder red stops with the surfaced seam.
      final first = await runMake(fx, zfaBin1);
      expect(exitCode, 1, reason: first);
      expect(first, contains('outcome=hand-delta-required'), reason: first);

      // The HAND-EDIT (the seam's designed remedy): replace `_arg0()`
      // with a representative Object.
      final testFile = File(fx.testPathOf('U6'));
      expect(testFile.readAsStringSync(), arg0Test);
      testFile.writeAsStringSync(handEditedRedTest);

      // Cycle 2: the pipeline now generates the real implementation.
      final zfaBin2 = await fx.writeFakeZfaBin(
        logPath: p.join(fx.root.path, 'fake_bin', 'zfa_calls_2.log'),
        sideEffectByArgv: {
          'func U6': fx.overwriteSubjectCommands('U6', realSubject),
        },
      );
      final second = await runMake(fx, zfaBin2);

      expect(
        exitCode,
        0,
        reason:
            'the hand-edited red re-certified and generation landed: '
            '$second',
      );
      expect(second, contains('outcome=green'), reason: second);
      // Generation RAN in cycle 2 — only the drift check's red re-cert
      // (from the UPDATED test) lets make proceed past it.
      final generationLog = await File(
        p.join(fx.root.path, 'fake_bin', 'zfa_calls_2.log'),
      ).readAsString();
      expect(
        generationLog,
        contains('func U6'),
        reason:
            'the drift check re-certified red from the hand-edited '
            'test, so generation ran: $generationLog',
      );
    });

    test('U-1323-5b: a hand-edit that satisfies the updated test '
        're-certifies GREEN from it — the skip transition, not a stale '
        'red skip', () async {
      const description = 'reason reports the error class';
      await fx.seedCertifiedRed(
        id: 'U6',
        description: description,
        testContent: arg0Test,
        subjectContent: throwingSubject,
      );
      final zfaBin1 = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
      final first = await runMake(fx, zfaBin1);
      expect(exitCode, 1, reason: first);

      final testFile = File(fx.testPathOf('U6'));
      testFile.writeAsStringSync(handEditedGreenTest);

      final zfaBin2 = await fx.writeFakeZfaBin(
        logPath: p.join(fx.root.path, 'fake_bin', 'zfa_calls_2.log'),
      );
      final second = await runMake(fx, zfaBin2);

      expect(
        exitCode,
        0,
        reason: 'the updated test passes — re-certified green: $second',
      );
      expect(
        second,
        contains('outcome=skipped'),
        reason:
            'the drift check re-ran the UPDATED test and certified '
            'green from it (issue #694 skip transition) — the certified-'
            'red entry never short-circuited the re-verification: $second',
      );
      // Generation never ran: the green came from the updated test —
      // the fake zfa was never spawned, so its call log was never
      // written.
      final generationLog = File(
        p.join(fx.root.path, 'fake_bin', 'zfa_calls_2.log'),
      );
      expect(
        generationLog.existsSync(),
        isFalse,
        reason:
            'the re-certified green skips generation — the fake zfa '
            'never spawned',
      );
    });
  });
}
