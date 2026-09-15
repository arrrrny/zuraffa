@Tags(['e2e'])
// Bug #1398 — crash-safe make: the killed/interrupted make recovers on
// resume, and only the honest crash class does (spec 1398).
//
// The misfire (#1398): a `zfa tdd run` killed by an external timeout
// mid-make leaves the subject mutated to its green shape with no green
// evidence. The resume's verify-red sees unexpected-green, then make
// refuses subject-drift — the crash class and the dishonest hand-edit
// class were indistinguishable, so the documented recovery dead-ended.
//
// Contract under test (spec 1398 SC-1..SC-6):
//   A1: a make SIGKILLed after the subject mutation leaves the interrupt
//       marker (SC-1); the resumed make ADOPTS the passing subject with
//       the EXPLICIT `adopted-interrupted` outcome — exit 0, green
//       evidence binding the CURRENT subject hash (SC-2).
//   A2: the identical drift WITHOUT a marker (the hand-edit class) keeps
//       the #1036 subject-drift refusal (SC-3).
//   A3: a crash marker never legitimizes a born-green placeholder — the
//       vacuous class keeps refusing (SC-4).
//   U5: a graceful make exit (refusal class) clears the marker — no
//       stale license (SC-6).
//   U6: the run driver grades `adopted-interrupted` a terminal make
//       success — the run completes (SC-5).
//   U7: the driver records the green evidence itself when the token's
//       exit code disagrees (the bug #986 pattern, #1398 messaging).
//
// A1 spawns the REAL `zfa tdd make` as a subprocess and SIGKILLs it after
// the pipeline's subject mutation lands — the honest crash, not a
// simulation. A2/A3/U5 run the real make in-process; U6/U7 drive the run
// driver against the fake zfa steps.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

const feature = '090-bug-1398-interrupt';

List<String> makeArgs(TddFixture fx, {String? id}) {
  final args = <String>['tdd', 'make', '--project', fx.root.path];
  if (id != null) args.add(id);
  return args;
}

List<String> verifyRedArgs(TddFixture fx, String id) => [
  'tdd',
  'verify-red',
  '--project',
  fx.root.path,
  id,
];

String markerPath(TddFixture fx) =>
    p.join(fx.featureDir, 'tdd', 'make-interrupt.json');

Map<String, dynamic>? readMarker(TddFixture fx) {
  final file = File(markerPath(fx));
  if (!file.existsSync()) return null;
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

String throwingSubject(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// GENERATED STUB — `zfa tdd gen $id`.
// behavior_id: $id
library;

/// Throws until the real implementation lands.
int $symbol() => throw UnimplementedError('$symbol not implemented');
''';
}

/// The make's own green shape — the mutation a killed make leaves behind.
/// Real logic (not the born-green placeholder), different bytes than the
/// certified stub.
String implementedSubject(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// GENERATED STUB — `zfa tdd gen $id`.
// behavior_id: $id
library;

int $symbol() {
  final base = 40;
  final step = 2;
  return base + step;
}
''';
}

/// A subject-driven test that fails on the throwing stub and passes on
/// the implementation (the honest red→green pair).
String subjectDrivenTest(String id, String description) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// GENERATED TEST — `zfa tdd gen $id` (spec 044-test-tdd-generation).
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

/// The born-green vacuous acceptance test (#1036's shape): passes on ANY
/// non-throwing body.
String vacuousAcceptanceTest(String id, String description) {
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

Future<String> subjectHashOf(TddFixture fx, String id) => File(
  fx.subjectPathOf(id),
).readAsBytes().then((b) => crypto.sha256.convert(b).toString());

/// Seed a green-evidence entry carrying a subject hash — the shape the
/// real make appends (issue #1036). [at] pins the entry's timestamp.
Future<void> seedGreenEvidenceWithHash(
  TddFixture fx,
  String behaviorId,
  String subjectHash, {
  String at = '2026-08-30T00:00:00.000Z',
}) async {
  final file = File(fx.cycleLogPath);
  if (!await file.exists()) {
    await file.parent.create(recursive: true);
    await file.writeAsString('# Cycle Log\n\n');
  }
  await file.writeAsString('''
## Cycle: $behaviorId (green)

- behavior: $behaviorId
- kind: green
- criterion: FR-003
- test: ${fx.testPathOf(behaviorId)}
- exit: 0
- subject-hash: $subjectHash
- at: $at

''', mode: FileMode.append);
}

void main() {
  group('bug 1398: the killed make recovers on resume (SC-1, SC-2)', () {
    test(
      'A1: SIGKILL mid-make leaves the marker; the resumed make adopts '
      '(outcome=adopted-interrupted, exit 0, current-hash green evidence)',
      () async {
        final fx = await TddFixture.create(featureName: feature);
        addTearDown(fx.dispose);
        addTearDown(() => exitCode = 0);
        const desc = 'returns 42 when invoked with no args';
        const id = 'A1';

        // The certified red: throwing stub + failing test + red evidence
        // (the same setup the #1331 re-drive tests use).
        await fx.seedCertifiedRed(
          id: id,
          description: desc,
          testContent: subjectDrivenTest(id, desc),
          subjectContent: throwingSubject(id),
        );
        final runner = CliRunner(exitOnCompletion: false);
        final redOut = await runner.runCapturing(verifyRedArgs(fx, id));
        expect(exitCode, 0, reason: redOut);

        // The kill harness: a fake zfa whose `func` step MUTATES the
        // subject to the green shape and then sleeps — the make process
        // is mid-flight with its work half-landed, exactly the crash
        // window the issue reports.
        final fakeBin = p.join(fx.fakeZfaDir, 'zfa-kill');
        await Directory(fx.fakeZfaDir).create(recursive: true);
        final subjectPath = fx.subjectPathOf(id);
        final killScript =
            '''
#!/bin/sh
# Bug #1398 kill harness: mutate the subject, then hold the make open.
echo "\$@" >> "${p.join(fx.fakeZfaDir, 'kill-argv.log')}"
STEP="\$2"
case "\$STEP" in
  func)
    cat > "$subjectPath" <<'ZFA_GREEN'
${implementedSubject(id).trim()}
ZFA_GREEN
    sleep 30
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
''';
        await File(fakeBin).writeAsString(killScript);
        Process.runSync('chmod', ['+x', fakeBin]);

        // Spawn the REAL make as a subprocess and kill it the moment the
        // subject mutation lands (post-mutation, pre-evidence).
        final repoBin = p.join(Directory.current.path, 'bin', 'zfa.dart');
        final makeProc = await Process.start(Platform.resolvedExecutable, [
          repoBin,
          'tdd',
          'make',
          '--project',
          fx.root.path,
          '--zfa-bin',
          fakeBin,
          id,
        ], workingDirectory: Directory.current.path);
        final mutated = await _waitFor(
          () =>
              File(subjectPath).existsSync() &&
              File(subjectPath).readAsStringSync().contains('base + step'),
          deadline: const Duration(minutes: 6),
          pollEvery: const Duration(milliseconds: 200),
        );
        expect(
          mutated,
          isTrue,
          reason: 'the kill window opened — the subject was mutated',
        );
        makeProc.kill(ProcessSignal.sigkill);
        final exitCode0 = await makeProc.exitCode.timeout(
          const Duration(seconds: 30),
          onTimeout: () => -9,
        );
        expect(
          exitCode0,
          anyOf(-9, 137, 255),
          reason: 'the make died by SIGKILL, not by its own exit',
        );

        // SC-1: the crash left the marker, and no green evidence.
        final crashed = readMarker(fx);
        expect(
          crashed,
          isNotNull,
          reason: 'a killed make leaves the interrupt marker behind',
        );
        expect(crashed!['behavior'], id);
        expect(crashed['status'], 'in-progress');
        final cycleAfterKill = await File(fx.cycleLogPath).readAsString();
        expect(
          cycleAfterKill,
          isNot(contains('## Cycle: $id (green)')),
          reason: 'the make died BEFORE any green evidence',
        );

        // SC-2: the resumed make adopts the interrupted subject.
        final out = await runner.runCapturing(makeArgs(fx, id: id));
        expect(exitCode, 0, reason: out);
        expect(out, contains('outcome=adopted-interrupted'), reason: out);
        expect(out, contains('issue #1398'), reason: out);
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(cycleLog, contains('## Cycle: $id (green)'));
        final currentHash = await subjectHashOf(fx, id);
        expect(
          cycleLog,
          contains('- subject-hash: $currentHash'),
          reason: 'the adoption binds the CURRENT subject shape',
        );
        // The marker was consumed by the graceful adoption exit.
        expect(
          readMarker(fx),
          isNull,
          reason: 'the adoption exit cleared the marker',
        );
      },
      timeout: const Timeout(Duration(minutes: 12)),
    );
  });

  group('bug 1398: the dishonest classes keep refusing (SC-3, SC-4)', () {
    test('A2: the identical drift WITHOUT a marker still refuses '
        'subject-drift — the hand-edit class', () async {
      final fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      addTearDown(() => exitCode = 0);
      const desc = 'returns 42 when invoked with no args';
      const id = 'A1';
      await fx.seedCertifiedRed(
        id: id,
        description: desc,
        testContent: subjectDrivenTest(id, desc),
        subjectContent: throwingSubject(id),
      );
      final runner = CliRunner(exitOnCompletion: false);
      final redOut = await runner.runCapturing(verifyRedArgs(fx, id));
      expect(exitCode, 0, reason: redOut);
      // The certified PAIR: a green evidence entry binding the stub's
      // hash (the #1331 B8b shape) — a GREEN-basis drift. Without it the
      // red-basis drift takes the #1162 hand-implementation fail-open and
      // the shape under test never reaches the refusal.
      final stubHash = await subjectHashOf(fx, id);
      await seedGreenEvidenceWithHash(fx, id, stubHash);

      // THE HAND EDIT: the subject is rewritten to the passing shape with
      // NO make ever started — no marker exists. Byte-identical crime
      // scene to the crash class except for the marker.
      await File(fx.subjectPathOf(id)).writeAsString(implementedSubject(id));
      expect(readMarker(fx), isNull, reason: 'no make ever started');

      final out = await runner.runCapturing(makeArgs(fx, id: id));
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('outcome=subject-drift'), reason: out);
      // The refusal appended NO green entry: the only green evidence in
      // the log is the seeded stub-hash certification — nothing binds the
      // hand-edited shape.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(
        '## Cycle: $id (green)'.allMatches(cycleLog).length,
        1,
        reason:
            'only the seeded certification — the refusal appended no '
            'green entry: $cycleLog',
      );
      final implementedHash = await subjectHashOf(fx, id);
      expect(
        cycleLog,
        isNot(contains('- subject-hash: $implementedHash')),
        reason: 'no green evidence ever binds the hand-edited shape',
      );
    });

    test('A3: a crash marker never legitimizes a born-green placeholder '
        '(the #1036 vacuous class)', () async {
      final fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      addTearDown(() => exitCode = 0);
      const desc = 'render returns a non-empty string for a populated task';
      const id = 'A2';
      await fx.seedCertifiedRed(
        id: id,
        description: desc,
        testContent: vacuousAcceptanceTest(id, desc),
        subjectContent: throwingSubject(id),
      );
      final runner = CliRunner(exitOnCompletion: false);
      final redOut = await runner.runCapturing(verifyRedArgs(fx, id));
      expect(exitCode, 0, reason: redOut);

      // The crash residue: a marker the killed make left AND the
      // born-green placeholder the killed make's rewrite left (the
      // vacuous shape — a constant body, no real logic).
      await File(markerPath(fx)).writeAsString(
        jsonEncode({
          'schema': 1,
          'feature': feature,
          'behavior': id,
          'pid': 999999,
          'at': DateTime.now().toUtc().toIso8601String(),
          'status': 'in-progress',
        }),
      );
      await File(fx.subjectPathOf(id)).writeAsString('''
library;

int a2_value() => 0;
''');

      final out = await runner.runCapturing(makeArgs(fx, id: id));
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('--> fix:'), reason: out);
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(
        cycleLog,
        isNot(contains('## Cycle: $id (green)')),
        reason: 'a vacuous subject is never adopted into green',
      );
      // The refusal is a graceful exit: the marker is consumed.
      expect(
        readMarker(fx),
        isNull,
        reason: 'the refusal exit cleared the marker (no stale license)',
      );
    });
  });

  group('bug 1398: marker hygiene on graceful exits (SC-6)', () {
    test('U5: a make refused before certification clears the marker it '
        'wrote — no stale license for a later hand-edit', () async {
      final fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      addTearDown(() => exitCode = 0);
      const desc = 'returns 42 when invoked with no args';
      const id = 'U-001';
      // Registry + test + subject, but NO red evidence: the make's
      // not-certified-red refusal path. A crash residue marker is already
      // on disk (the previous make died mid-flight) — the graceful
      // refusal must CONSUME it, leaving no stale license behind.
      await fx.registerBehavior(id: id, description: desc);
      await File(markerPath(fx)).writeAsString(
        jsonEncode({
          'schema': 1,
          'feature': feature,
          'behavior': id,
          'pid': 999999,
          'at': DateTime.now().toUtc().toIso8601String(),
          'status': 'in-progress',
        }),
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(makeArgs(fx, id: id));
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('not-certified-red'), reason: out);
      // The refusal is graceful: the marker (pre-seeded crash residue)
      // is cleared by the summary exit.
      expect(
        readMarker(fx),
        isNull,
        reason: 'every graceful make exit clears the marker',
      );
    });
  });

  group('bug 1398: the driver accepts the adopted-interrupted token '
      '(SC-5, FR-6)', () {
    test('U6: a make reporting outcome=adopted-interrupted (exit 0) is a '
        'terminal make success — the run completes', () async {
      final fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      addTearDown(() => exitCode = 0);
      await fx.writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'U-001',
          description: 'the U-001 behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.registerBehavior(id: 'U-001', description: 'the U-001 behavior');
      // The resumed make's shape: exit 0 with the adopted-interrupted
      // token and the green evidence the real make writes (the fake's
      // `adopt-interrupted` shape mirrors the real `zfa tdd make`
      // crash-recovery adoption).
      await fx.setStepOutcome('make', 'U-001', 'adopt-interrupted');
      fx.clearStepInvocations();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(exitCode, 0, reason: out);
      expect(out, contains('result=complete'), reason: out);
      // The exit-0 success path prints the outcome token directly (the
      // `make -> green (...)` reclassification line is the #986
      // disagreement arm's shape — that is U7's business).
      expect(
        out,
        contains('[run] U-001 make -> adopted-interrupted'),
        reason: out,
      );
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: U-001 (green)'));
    });

    test('U7: a make whose adopted-interrupted token disagrees with its '
        'exit code is still terminal — the driver records the green '
        'evidence itself (bug #986 pattern)', () async {
      final fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      addTearDown(() => exitCode = 0);
      await fx.writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'U-001',
          description: 'the U-001 behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.registerBehavior(id: 'U-001', description: 'the U-001 behavior');
      // The disagreement shape: the token with a non-zero exit (binary
      // skew) — the token is the terminal classification.
      await fx.setStepOutcome('make', 'U-001', 'adopted-interrupted');
      fx.clearStepInvocations();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(exitCode, 0, reason: out);
      expect(out, contains('result=complete'), reason: out);
      expect(out, contains('make -> green (adopted-interrupted)'), reason: out);
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: U-001 (green)'));
      expect(
        cycleLog,
        contains('zfa tdd make U-001 (adopted-interrupted)'),
        reason: 'the driver-recorded entry names the #1398 transition',
      );
      expect(cycleLog, contains('issue #1398'), reason: out);
    });
  });
}

/// Poll [probe] until it returns true or the [deadline] passes.
Future<bool> _waitFor(
  bool Function() probe, {
  required Duration deadline,
  required Duration pollEvery,
}) async {
  final end = DateTime.now().add(deadline);
  while (DateTime.now().isBefore(end)) {
    if (probe()) return true;
    await Future<void>.delayed(pollEvery);
  }
  return false;
}
