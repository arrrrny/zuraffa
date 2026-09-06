// Slow-tier end-to-end tests for bug #1162 — bug subjects can never
// certify green: the subject-drift guard dead-ends the loop for
// hand-implemented subjects (the gen'd test header's own instruction),
// and the unexpressible planner dead-ends prose bug scenarios.
//
// Contract under test (issue #1162):
//   1. The #1036 drift guard FAILS OPEN when the certified-red behavior's
//      subject was hand-implemented (the scenario assertions genuinely
//      execute — the target test passes and the subject is not a
//      born-green placeholder): the #694 skip transition re-binds the
//      green evidence to the implemented subject shape.
//   2. `zfa tdd verify-red <id> --re-certify` is the explicit transition:
//      a passing target test with certified red evidence and a changed
//      subject appends GREEN evidence binding the NEW subject hash and
//      the passing transcript. Born-green behaviors (no red evidence, or
//      a green against the certified red shape itself) are still refused.
//   3. The placeholder refusal classes are PRESERVED: the #1036
//      func-scaffold rewrite class and the scaffolded marker still refuse.
//   4. A bug feature's unexpressible acceptance make composes against
//      stub-only unit subjects (the bug extension's sanctioned path).
//
// Slow tier: spawns real `dart test` subprocesses in throwaway projects.
@Tags(['slow'])
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// The sha256 of the subject file (the evidence `subject-hash:` value).
Future<String> subjectHashOf(TddFixture fx, String id) async =>
    sha256.convert(await File(fx.subjectPathOf(id)).readAsBytes()).toString();

List<String> makeArgs1162(TddFixture fx, {String? id, String? zfaBin}) {
  final args = <String>['tdd', 'make', '--project', fx.root.path];
  if (zfaBin != null) args.addAll(['--zfa-bin', zfaBin]);
  if (id != null) args.add(id);
  return args;
}

List<String> verifyRedArgs1162(
  TddFixture fx,
  String id, {
  bool reCertify = false,
}) {
  final args = <String>[
    'tdd',
    'verify-red',
    '--project',
    fx.root.path,
    if (reCertify) '--re-certify',
    id,
  ];
  return args;
}

/// The gen-shaped THROWING subject stub (`zfa tdd gen A1`): the fixture
/// convention declares `<snake>_value` (the symbol the paired tests call).
String throwingSubject1162(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// GENERATED STUB — `zfa tdd gen $id`.
library;

/// Scenario runner for behavior $id.
///
/// Throws [UnimplementedError] until the real implementation lands.
int $symbol() => throw UnimplementedError('$symbol not implemented');
''';
}

/// A HAND IMPLEMENTATION (the #1162 sanctioned state): real logic, not a
/// pipeline scaffold shape — computes the answer from parts.
String handImplementedSubject(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// Hand-implemented per the paired test header's instruction.
library;

int $symbol() {
  final base = 40;
  final step = 2;
  return base + step;
}
''';
}

/// A subject-driven test that fails on the stub and passes on the real
/// implementation (the honest red -> green pair) — the GEN shape: the
/// subject call is wrapped so the failure is an authored expect mismatch
/// (an assertion), never an uncaught error (spec 046's honest-red rule).
String subjectDrivenTest1162(String id, String description) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    final Object? result = (() {
      try {
        return $symbol();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, equals(42));
  });
}
''';
}

/// The born-green vacuous acceptance test: fails ONLY when the subject
/// throws — any non-throwing body passes it (the #1036 vacuity shape).
String vacuousAcceptanceTest1162(String id, String description) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect($symbol, isNot(throwsA(isA<UnimplementedError>())));
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

  group('bug 1162: the drift guard fails open for implemented subjects', () {
    test(
      'A-1162a: a hand-implemented subject certifies green through the skip '
      'transition (outcome=skipped, green evidence re-bound to the new hash)',
      () async {
        const desc = 'returns 42 when invoked with no args';
        await fx.seedCertifiedRed(
          id: 'A1',
          description: desc,
          testContent: subjectDrivenTest1162('A1', desc),
          subjectContent: throwingSubject1162('A1'),
        );
        final runner = CliRunner(exitOnCompletion: false);

        // Certify red against the THROWING stub (records its hash).
        final redOut = await runner.runCapturing(verifyRedArgs1162(fx, 'A1'));
        expect(exitCode, 0, reason: redOut);

        // Hand-implement the subject — exactly what the gen'd test header
        // instructs. The test now genuinely passes.
        await File(
          fx.subjectPathOf('A1'),
        ).writeAsString(handImplementedSubject('A1'));

        // The make: the drift check is green, the subject drifted from the
        // certified red shape — issue #1162's dead end. The guard must FAIL
        // OPEN: the skip transition re-binds the green evidence.
        final out = await runner.runCapturing(makeArgs1162(fx, id: 'A1'));
        expect(exitCode, 0, reason: out);
        expect(out, contains('outcome=skipped'));
        expect(out, contains('issue #1162'));

        // Green evidence appended, bound to the IMPLEMENTED subject hash.
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(cycleLog, contains('## Cycle: A1 (green)'));
        final implementedHash = await subjectHashOf(fx, 'A1');
        expect(cycleLog, contains('- subject-hash: $implementedHash'));
      },
    );

    test(
      'A-1162b: the #1036 refusal classes are preserved — the func-scaffold '
      'placeholder still refuses (with the re-certify remedy named)',
      () async {
        const desc = 'returns 42 when invoked with no args';
        await fx.seedCertifiedRed(
          id: 'A2',
          description: desc,
          // The born-green vacuity: passes on ANY non-throwing body.
          testContent: vacuousAcceptanceTest1162('A2', desc),
          subjectContent: throwingSubject1162('A2'),
        );
        final runner = CliRunner(exitOnCompletion: false);
        final redOut = await runner.runCapturing(verifyRedArgs1162(fx, 'A2'));
        expect(exitCode, 0, reason: redOut);

        // The failed-make rewrite class: the vacuous pipeline scaffold
        // (`return 0;` — the declared-stub body shape).
        await File(fx.subjectPathOf('A2')).writeAsString('''
library;

int a2_value() => 0;
''');

        final out = await runner.runCapturing(makeArgs1162(fx, id: 'A2'));
        expect(
          exitCode,
          isNot(0),
          reason: 'the born-green placeholder class must still refuse: $out',
        );
        expect(out, contains('--> fix:'));
        expect(out, contains('--re-certify'));
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(cycleLog, isNot(contains('## Cycle: A2 (green)')));
      },
    );
  });

  group('bug 1162: verify-red --re-certify', () {
    test('A-1162c: the explicit transition re-binds green evidence to the '
        'implemented subject with the passing transcript, and the follow-up '
        'make skips cleanly', () async {
      const desc = 'returns 42 when invoked with no args';
      await fx.seedCertifiedRed(
        id: 'A3',
        description: desc,
        testContent: subjectDrivenTest1162('A3', desc),
        subjectContent: throwingSubject1162('A3'),
      );
      final runner = CliRunner(exitOnCompletion: false);
      final redOut = await runner.runCapturing(verifyRedArgs1162(fx, 'A3'));
      expect(exitCode, 0, reason: redOut);

      await File(
        fx.subjectPathOf('A3'),
      ).writeAsString(handImplementedSubject('A3'));

      final out = await runner.runCapturing(
        verifyRedArgs1162(fx, 'A3', reCertify: true),
      );
      expect(exitCode, 0, reason: out);
      expect(out, contains('classification=re-certified'));
      expect(out, contains('certified=true'));

      // The green entry carries the NEW subject hash, the passing
      // transcript, and the #1162 re-certification marker.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: A3 (green)'));
      final implementedHash = await subjectHashOf(fx, 'A3');
      expect(cycleLog, contains('- subject-hash: $implementedHash'));
      expect(cycleLog, contains('- evidence: issue #1162 re-certification'));

      // The follow-up make: the drift guard now matches the certified
      // green hash — the skip transition proceeds.
      final makeOut = await runner.runCapturing(makeArgs1162(fx, id: 'A3'));
      expect(exitCode, 0, reason: makeOut);
      expect(makeOut, contains('outcome=skipped'));
    });

    test('A-1162d: a born-green behavior (no certified red) is refused — no '
        'evidence written', () async {
      const desc = 'returns 42 when invoked with no args';
      await fx.registerBehavior(
        id: 'U9',
        description: desc,
        testContent: subjectDrivenTest1162('U9', desc),
      );
      final subjectFile = File(fx.subjectPathOf('U9'));
      await subjectFile.parent.create(recursive: true);
      await subjectFile.writeAsString(handImplementedSubject('U9'));
      final runner = CliRunner(exitOnCompletion: false);

      final out = await runner.runCapturing(
        verifyRedArgs1162(fx, 'U9', reCertify: true),
      );
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('unexpected-green'));
      expect(out, contains('no certified red evidence'));
      final cycleLogFile = File(fx.cycleLogPath);
      expect(
        cycleLogFile.existsSync(),
        isFalse,
        reason: 'no evidence written — the cycle log is never created',
      );
    });
  });

  group('bug 1162: the unexpressible path for bug features', () {
    test('A-1162e: a bug feature\'s unexpressible acceptance make composes '
        'against stub-only unit subjects and certifies green', () async {
      final fx2 = await TddFixture.create(
        featureName: 'bug-1162-fixture',
        // Scoped GREEN suite: the baseline must produce a usable
        // snapshot on every platform (the scoped file is green).
        suiteTemplate: 'dart test test/scoped_baseline_test.dart',
      );
      addTearDown(fx2.dispose);
      final scopedBaseline = File(
        p.join(fx2.root.path, 'test', 'scoped_baseline_test.dart'),
      );
      await scopedBaseline.parent.create(recursive: true);
      await scopedBaseline.writeAsString('''
import 'package:test/test.dart';

void main() {
  test('scoped baseline stays green', () {
    expect(1, equals(1));
  });
}
''');

      const desc =
          'it completes and a parseable baseline snapshot is '
          'cached (not a `timedOut: true` record).';
      await fx2.seedCertifiedRed(
        id: 'A1',
        description: desc,
        testContent: vacuousAcceptanceTest1162('A1', desc),
        subjectContent: throwingSubject1162('A1'),
      );
      // The unit row: gen'd (registry + stub subject on disk), NOT green,
      // NOT wired — the #1162 bug-feature state.
      await fx2.seedCertifiedRed(
        id: 'U1',
        description: 'the driver forwards its timeout override.',
        sourceCriterion: 'FR-001',
        subjectContent: throwingSubject1162('U1'),
      );
      await fx2.seedTestList([
        (
          id: 'A1',
          description: desc,
          traces: 'AC-1',
          state: 'PENDING',
          kind: 'acceptance',
        ),
        (
          id: 'U1',
          description: 'the driver forwards its timeout override.',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);

      // The composition step's side effect: the composed subject
      // references the stub anchor WITHOUT calling it (the sanctioned
      // pipeline shape) — non-throwing, so the acceptance test passes.
      final zfaBin = await fx2.writeFakeZfaBin(
        logPath: fx2.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd compose': fx2.overwriteSubjectCommands('A1', '''
// GENERATED IMPLEMENTATION — `zfa tdd compose A1` (issue #642).
library;

import '../lib/u1_subject.dart' as anchor0;

void a1_value() {
  // Composition anchor: references the feature's unit subjects.
  // ignore: unused_local_variable
  final composedUnitAnchors = <Function>[anchor0.u1_value];
}
'''),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs1162(fx2, id: 'A1', zfaBin: zfaBin),
      );
      expect(exitCode, 0, reason: out);
      expect(out, contains('stub-only'));
      expect(out, contains('outcome=green'));

      // Green evidence appended for the acceptance behavior.
      final cycleLog = await File(fx2.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: A1 (green)'));
      // The plan executed the compose step against the stub anchor: the
      // fake zfa bin logged the compose argv (the pipeline spawned it).
      final fakeLog = await File(fx2.fakeZfaLogPath).readAsString();
      expect(fakeLog, contains('compose'));
    });
  });
}
