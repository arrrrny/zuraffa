@Tags(['e2e'])
// Bug #1669 — a NON-adopting graceful exit after a crash must not consume
// the interrupt marker while the crash mutation survives (the #1398 wedge,
// reachable one refusal later).
//
// The misfire: `_printSummary` (the every-exit-path funnel) cleared the
// write-ahead marker on EVERY graceful exit — including a refusal. A make
// killed mid-flight (subject mutated green + marker present), resumed into
// an UNRELATED refusal (flaky target test → generation-error, preflight
// failure, log loss → not-certified-red), lost the marker while the crash
// mutation lived on: the next resume read byte-identical to the dishonest
// hand-edit class and dead-ended at the #1036 subject-drift refusal.
//
// Contract under test:
//   A1: inherited marker + live implemented-subject drift + a non-adopting
//       refusal → the marker SURVIVES on disk and the run says so
//       (issue #1669) — the crash record is not consumed by a refusal.
//   A2: inherited marker + NO drift (the subject still matches the
//       certified hash) → the refusal consumes the marker — the drift
//       never existed, no stale license.
//   A3: identical drift but NO inherited marker (the dishonest hand-edit
//       class) → the refusal consumes THIS run's own marker — a make that
//       began clean never forges a crash record; the #1036 dead-end stands.
//   A4: the kept marker un-wedges the resume — with certified red restored,
//       the resumed make adopts the passing subject (adopted-interrupted,
//       exit 0), binds the CURRENT subject hash, and consumes the marker.
//   A5: inherited marker + the born-green placeholder class → the marker is
//       consumed — pinned by the shipped spec-1398 A3 test
//       (`bug_1398_make_interrupt_recovery_test.dart`), regression-run, not
//       re-authored here.
//   A6: inherited marker + implemented crash mutation + a generation-error
//       refusal (the flaky-target-test arm of the wedge narrative) → the
//       marker SURVIVES — the keep is refusal-flavor-agnostic: the funnel
//       branches on `_interruptInherited` + disk state only.
//
// Every shape runs the REAL make in-process (CliRunner + TddFixture, the
// issue #1308 driver-suite convention), like the spec-1398 recovery file.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

const feature = '090-bug-1669-marker-wedge';

List<String> makeArgs(TddFixture fx, {String? id, String? zfaBin}) {
  final args = <String>['tdd', 'make', '--project', fx.root.path];
  if (zfaBin != null) args.addAll(['--zfa-bin', zfaBin]);
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

/// A crash-residue marker the killed make left behind (the spec-1398 A3
/// seeding shape): a same-behavior in-progress record on disk BEFORE the
/// make under test begins, so the make INHERITS the crash provenance.
Future<void> writeCrashMarker(TddFixture fx, String id) async {
  await File(markerPath(fx)).parent.create(recursive: true);
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

/// A crash mutation that does NOT pass its own test (returns 41, the test
/// expects 42): the resumed make reaches the generation pipeline and dies
/// in it (the generation-error flavor), while the bytes still differ from
/// the certified stub, so the crash drift is live.
String brokenSubject(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// GENERATED STUB — `zfa tdd gen $id`.
// behavior_id: $id
library;

int $symbol() {
  final base = 40;
  final step = 1;
  return base + step;
}
''';
}

/// The build step's analyze-gate refusal carrying analyzer ERRORS (the
/// #942 class): whatever the warnings policy, errors keep the honest
/// `generation-error` stop. (No apostrophes — the fake bin echoes these
/// through single-quoted shell lines.)
const generationErrorBuildStdout = [
  '   error - lib/src/a_subject.dart:5:8 - The name A6Subject is defined in two libraries. - ambiguous_import',
  '❌ dart analyze reported 1 error(s) and 0 warning(s) — generated code does not compile cleanly.',
];

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

/// Seed a red-evidence entry carrying a subject hash — the shape verify-red
/// appends on a real certification (issue #1036). Used to model the
/// recovery step of A4 (the certification restored after the log loss).
Future<void> seedRedEvidenceWithHash(
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
## Cycle: $behaviorId (red)

- behavior: $behaviorId
- kind: red
- classification: assertionFailure
- criterion: FR-003
- test: ${fx.testPathOf(behaviorId)}
- command: `dart test ${fx.testPathOf(behaviorId)} --plain-name "$behaviorId"`
- exit: 1
- subject-hash: $subjectHash
- at: $at

''', mode: FileMode.append);
}

/// The wedge state of scenarios A1/A2/A4: a behavior certified GREEN over
/// the STUB (the log-loss flavor — the red entry is gone, the certified
/// hash survives), with the registry record and the honest subject-driven
/// test on disk. The caller decides the on-disk subject shape.
Future<void> seedGreenCertifiedBehavior(
  TddFixture fx, {
  required String id,
  required String description,
}) async {
  await fx.registerBehavior(
    id: id,
    description: description,
    testContent: subjectDrivenTest(id, description),
  );
  final subjectFile = File(fx.subjectPathOf(id));
  await subjectFile.parent.create(recursive: true);
  await subjectFile.writeAsString(throwingSubject(id));
  final stubHash = await subjectHashOf(fx, id);
  await seedGreenEvidenceWithHash(fx, id, stubHash);
}

void main() {
  group('bug 1669: a non-adopting refusal keeps a live crash record (A1)', () {
    test(
      'A1: inherited marker + implemented crash mutation + '
      'not-certified-red refusal → the marker SURVIVES the graceful exit',
      () async {
        final fx = await TddFixture.create(featureName: feature);
        addTearDown(fx.dispose);
        addTearDown(() => exitCode = 0);
        const desc = 'returns 42 when invoked with no args';
        const id = 'A1';
        await seedGreenCertifiedBehavior(fx, id: id, description: desc);

        // The crash residue: the marker AND the mutation a killed make
        // left behind — a real implemented subject, not a placeholder.
        await writeCrashMarker(fx, id);
        await File(fx.subjectPathOf(id)).writeAsString(implementedSubject(id));

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(makeArgs(fx, id: id));
        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('outcome=not-certified-red'), reason: out);
        // THE FIX: the crash record survives the non-adopting exit.
        expect(
          readMarker(fx),
          isNotNull,
          reason: 'the refusal must not consume a live crash record: $out',
        );
        // ...and the run says so out loud.
        expect(out, contains('issue #1669'), reason: out);
        // The refusal appended NO green evidence — nothing binds the
        // mutated shape yet.
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(
          '## Cycle: $id (green)'.allMatches(cycleLog).length,
          1,
          reason:
              'only the seeded certification; the refusal appended nothing: '
              '$cycleLog',
        );
        final implementedHash = await subjectHashOf(fx, id);
        expect(
          cycleLog,
          isNot(contains('- subject-hash: $implementedHash')),
          reason: 'no green evidence may bind the mutation on a refusal',
        );
      },
    );
  });

  group('bug 1669: drift-free refusals keep consuming (A2)', () {
    test('A2: inherited marker + NO drift (subject matches the certified '
        'hash) → the refusal consumes the marker', () async {
      final fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      addTearDown(() => exitCode = 0);
      const desc = 'returns 42 when invoked with no args';
      const id = 'A2';
      await seedGreenCertifiedBehavior(fx, id: id, description: desc);
      // The crash left a marker but NO mutation: the subject still
      // matches the certified hash (the kill landed pre-mutation).
      await writeCrashMarker(fx, id);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(makeArgs(fx, id: id));
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('outcome=not-certified-red'), reason: out);
      expect(
        readMarker(fx),
        isNull,
        reason:
            'drift never existed — the refusal consumes the marker '
            '(no stale license): $out',
      );
    });
  });

  group('bug 1669: a clean-begin make never forges a crash record (A3)', () {
    test(
      'A3: identical drift WITHOUT an inherited marker (the hand-edit '
      'class) → the subject-drift refusal consumes this run\'s own marker',
      () async {
        final fx = await TddFixture.create(featureName: feature);
        addTearDown(fx.dispose);
        addTearDown(() => exitCode = 0);
        const desc = 'returns 42 when invoked with no args';
        const id = 'A3';
        // The certified pair (the spec-1398 A2 shape): red evidence over
        // the stub (a real verify-red certification) plus the green
        // evidence binding the stub's hash — a GREEN-basis drift.
        await fx.seedCertifiedRed(
          id: id,
          description: desc,
          testContent: subjectDrivenTest(id, desc),
          subjectContent: throwingSubject(id),
        );
        final runner = CliRunner(exitOnCompletion: false);
        final redOut = await runner.runCapturing(verifyRedArgs(fx, id));
        expect(exitCode, 0, reason: redOut);
        final stubHash = await subjectHashOf(fx, id);
        await seedGreenEvidenceWithHash(fx, id, stubHash);

        // THE HAND EDIT: the subject rewritten to the passing shape with
        // NO make ever started — no marker on disk before this run.
        await File(fx.subjectPathOf(id)).writeAsString(implementedSubject(id));
        expect(readMarker(fx), isNull, reason: 'no make ever started');

        final out = await runner.runCapturing(makeArgs(fx, id: id));
        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('outcome=subject-drift'), reason: out);
        // This run's own marker is consumed: the #1036 dead-end for the
        // dishonest class stands, with no forged crash record.
        expect(
          readMarker(fx),
          isNull,
          reason:
              'a make that began clean must not leave a crash record '
              'behind: $out',
        );
      },
    );
  });

  group('bug 1669: the kept marker un-wedges the resume (A4)', () {
    test('A4: wedge state → refusal keeps the marker → certified red '
        'restored → the resume ADOPTS (adopted-interrupted, exit 0, '
        'current-hash green evidence) and consumes the marker', () async {
      final fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      addTearDown(() => exitCode = 0);
      const desc = 'returns 42 when invoked with no args';
      const id = 'A4';
      await seedGreenCertifiedBehavior(fx, id: id, description: desc);
      // The stub's hash, captured BEFORE the crash mutation overwrites
      // the subject — the certified shape the recovery re-certifies.
      final stubHash = await subjectHashOf(fx, id);
      await writeCrashMarker(fx, id);
      await File(fx.subjectPathOf(id)).writeAsString(implementedSubject(id));

      final runner = CliRunner(exitOnCompletion: false);
      // Step 1: the unrelated refusal — the wedge entry — must KEEP the
      // marker (the A1 contract).
      final refusedOut = await runner.runCapturing(makeArgs(fx, id: id));
      expect(exitCode, isNot(0), reason: refusedOut);
      expect(readMarker(fx), isNotNull, reason: refusedOut);

      // Step 2: the recovery — the certified red is restored (the
      // operator re-certifies from a surviving transcript).
      await seedRedEvidenceWithHash(fx, id, stubHash);

      // Step 3: the resume — the marker proves the crash, the passing
      // target test re-certifies green against the subject it mutated.
      final out = await runner.runCapturing(makeArgs(fx, id: id));
      expect(exitCode, 0, reason: out);
      expect(out, contains('outcome=adopted-interrupted'), reason: out);
      expect(out, contains('issue #1398'), reason: out);
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      final currentHash = await subjectHashOf(fx, id);
      expect(
        cycleLog,
        contains('- subject-hash: $currentHash'),
        reason: 'the adoption binds the CURRENT subject shape: $cycleLog',
      );
      expect(
        readMarker(fx),
        isNull,
        reason: 'the adoption exit consumed the crash record: $out',
      );
    });
  });

  group('bug 1669: the keep holds on a second refusal flavor (A6)', () {
    test(
      'A6: inherited marker + implemented crash mutation + '
      'generation-error refusal → the marker SURVIVES the graceful exit',
      () async {
        final fx = await TddFixture.create(featureName: feature);
        addTearDown(fx.dispose);
        addTearDown(() => exitCode = 0);
        const desc = 'returns 42 when invoked with no args';
        const id = 'A6';
        // The certified pair, minted for real (the A3 recipe): the
        // registry seed's red entry is hashless, so a REAL verify-red run
        // appends the red certification carrying the stub's subject hash
        // — the certified basis the funnel probe compares against.
        await fx.seedCertifiedRed(
          id: id,
          description: desc,
          testContent: subjectDrivenTest(id, desc),
        );
        final runner = CliRunner(exitOnCompletion: false);
        final redOut = await runner.runCapturing(verifyRedArgs(fx, id));
        expect(exitCode, 0, reason: redOut);

        // The crash residue: the marker AND a mutation the killed make
        // left mid-flight — a WRONG implementation: it still fails the
        // target test (the flaky-target-test arm), but its bytes differ
        // from the certified stub, so the crash drift is live.
        await writeCrashMarker(fx, id);
        await File(fx.subjectPathOf(id)).writeAsString(brokenSubject(id));

        // The pipeline dies at the terminal build gate (analyzer errors →
        // the honest generation-error stop, the #942 class).
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: fx.fakeZfaLogPath,
          stdoutByArgv: {'build': generationErrorBuildStdout},
          exitByArgv: {'build': 1},
        );

        final out = await runner.runCapturing(
          makeArgs(fx, id: id, zfaBin: zfaBin),
        );
        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('outcome=generation-error'), reason: out);
        // THE FIX on the second flavor: the crash record survives the
        // non-adopting exit — the keep is refusal-flavor-agnostic.
        expect(
          readMarker(fx),
          isNotNull,
          reason:
              'the generation-error must not consume a live crash '
              'record: $out',
        );
        expect(out, contains('issue #1669'), reason: out);
        // The refusal appended NO green evidence — nothing binds the
        // broken mutation.
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(
          cycleLog,
          isNot(contains('## Cycle: $id (green)')),
          reason:
              'no green evidence may bind the mutation on a refusal: '
              '$cycleLog',
        );
        // And the mutation itself survives the failed make (the wedge
        // precondition the kept marker exists for: with the record gone
        // the next resume would read byte-identical to a hand-edit).
        final subject = await File(fx.subjectPathOf(id)).readAsString();
        expect(subject, contains('step = 1'), reason: subject);
      },
    );
  });
}
