@Tags(['slow'])
// Bug #1331 — the re-drive dead-end: after `zfa tdd reset`, make refuses
// the re-driven behavior with `subject-drift` (the surviving PRE-reset
// green evidence's subject hash never matches the re-driven subject),
// the run driver stops at `<id>:make` (`result=stopped`), and doctor's
// prescribed recovery loop (reset → run) can never complete.
//
// Contract under test (issue #1331, SC-4..SC-6):
//   - B6: make ADOPTS the re-drive class — a behavior tombstoned by the
//     last reset whose surviving green evidence predates the tombstone
//     and whose target test passes against the on-disk subject certifies
//     green with the EXPLICIT `adopted` outcome (exit 0, green evidence
//     binding the CURRENT subject hash).
//   - B7: the run driver accepts `adopted` as a terminal make success —
//     the loop advances (green → refactor → done).
//   - B8: every non-re-drive refusal class is PRESERVED: a green-basis
//     drift whose last green evidence postdates the reset, an identical
//     drift with NO reset tombstone, and the born-green placeholder
//     class all still refuse.
//   - B9: doctor's evidence-without-artifact prescription names the
//     mechanics the run actually performs (make adopts).
//   - B10: the recovery loop composes: reset → doctor prescribes run →
//     run completes → doctor healthy.
//
// B6/B8 spawn the real `zfa tdd make`/`verify-red` (real `dart test`
// subprocesses in throwaway projects); B7/B9/B10 drive the CLI in-process
// against the fake zfa binary.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

const feature = '090-bug-1331-redrive';

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

List<String> resetArgs(TddFixture fx, String featureName) => [
  'tdd',
  'reset',
  featureName,
  '--project',
  fx.root.path,
];

List<String> doctorArgs(TddFixture fx, String featureName) => [
  'tdd',
  'doctor',
  featureName,
  '--project',
  fx.root.path,
];

Map<String, dynamic> envelope(String out) {
  final lines = out
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  return jsonDecode(lines.last) as Map<String, dynamic>;
}

/// The gen-shaped THROWING subject stub (`zfa tdd gen A1`): the certified
/// red shape.
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

/// A HAND IMPLEMENTATION (the complete-but-unowned re-driven subject):
/// real logic, different bytes than the stub.
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
// behavior_id: $id
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
).readAsBytes().then(sha256.convert).then((h) => h.toString());

/// Append a green-evidence entry carrying a subject hash — the shape the
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

/// Overwrite the feature registry with exactly [records].
Future<void> seedRegistry(
  TddFixture fx,
  String featureName,
  List<Map<String, dynamic>> records,
) async {
  final file = File(
    p.join(fx.root.path, 'specs', featureName, 'tdd', 'artifacts.json'),
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(
    jsonEncode({'feature': featureName, 'records': records}),
  );
}

Map<String, dynamic> recordOf(
  TddFixture fx,
  String featureName,
  String id,
  String description,
) => {
  'behavior_id': id,
  'feature': featureName,
  'source_criterion': 'FR-003',
  'test_path': fx.testPathOf(id),
  'subject_path': fx.subjectPathOf(id),
  'runnable_test_name': '${fx.testPathOf(id)}::$id::$description',
  'test_ownership': 'created',
  'subject_ownership': 'created',
  'created_at': DateTime.now().toUtc().toIso8601String(),
};

void main() {
  group('bug 1331: make adopts the re-drive class (SC-4)', () {
    test('B6: a tombstoned behavior whose surviving green evidence predates '
        "the reset adopts the passing subject — outcome=adopted, exit 0, "
        'green evidence binding the CURRENT subject hash', () async {
      final fx = await TddFixture.create(featureName: feature);
      const desc = 'returns 42 when invoked with no args';
      const id = 'A1';

      // The completed drive: certified red (throwing stub), then green
      // evidence binding the STUB's subject hash.
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

      // THE RESET: drops the record and tombstones the behavior (the
      // user's explicit "start over"). Whether the files survive is
      // reset's own contract (spec 1331 SC-1); the re-drive re-creates
      // them either way.
      final resetOut = await runner.runCapturing(resetArgs(fx, feature));
      expect(exitCode, 0, reason: resetOut);
      expect(
        await File(p.join(fx.featureDir, 'tdd', 'journal.json')).readAsString(),
        contains('"phase": "reset"'),
        reason: 'the reset tombstone is the re-drive class signal',
      );

      // THE RE-DRIVE (what fresh gen + the re-registered ownership
      // produce): the subject is now the COMPLETE-but-unowned
      // implementation — different bytes than the certified stub — and
      // the record exists again.
      await File(fx.testPathOf(id)).writeAsString(subjectDrivenTest(id, desc));
      await File(fx.subjectPathOf(id)).writeAsString(implementedSubject(id));
      await seedRegistry(fx, feature, [recordOf(fx, feature, id, desc)]);

      // The make: pre-fix this dead-ends with subject-drift (the old
      // green hash never matches the re-driven subject); post-fix the
      // tombstoned re-drive class ADOPTS.
      final out = await runner.runCapturing(makeArgs(fx, id: id));
      expect(exitCode, 0, reason: out);
      expect(out, contains('outcome=adopted'), reason: out);
      expect(out, contains('issue #1331'), reason: out);

      // The green evidence binds the CURRENT (implemented) subject
      // hash — any later drift still refuses.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: $id (green)'));
      final implementedHash = await subjectHashOf(fx, id);
      expect(cycleLog, contains('- subject-hash: $implementedHash'));

      fx.dispose();
      exitCode = 0;
    });
  });

  group('bug 1331: the run loop accepts adopted (SC-4, SC-6)', () {
    test('B7: a make reporting outcome=adopted (exit 0, green evidence '
        'written — the real make shape) is a terminal make success — the '
        'loop advances and the run completes', () async {
      final fx = await TddFixture.create(featureName: feature);
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
      await seedRegistry(fx, feature, [
        recordOf(fx, feature, 'U-001', 'the U-001 behavior'),
      ]);
      // The re-drive make: exit 0 with the adopted outcome token and
      // the green evidence the real make writes (the fake's `adopt`
      // shape mirrors the real `zfa tdd make` adopted outcome).
      await fx.setStepOutcome('make', 'U-001', 'adopt');
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
      expect(fx.stepInvocations(), [
        'gen U-001',
        'verify-red U-001',
        'make U-001',
        'refactor U-001',
      ], reason: out);
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: U-001 (green)'));

      fx.dispose();
      exitCode = 0;
    });

    test('B7b: a make whose adopted token disagrees with its exit code is '
        'still terminal — the driver records the green evidence the child '
        'did not write (the #986 pattern) and advances', () async {
      final fx = await TddFixture.create(featureName: feature);
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
      await seedRegistry(fx, feature, [
        recordOf(fx, feature, 'U-001', 'the U-001 behavior'),
      ]);
      // The disagreement shape: the adopted token with a non-zero exit
      // (binary skew) — the token is the terminal classification.
      await fx.setStepOutcome('make', 'U-001', 'adopted');
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
      expect(out, contains('make -> green (adopted)'), reason: out);
      // The driver recorded the green evidence the child skipped.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: U-001 (green)'));
      expect(
        cycleLog,
        contains('zfa tdd make U-001 (adopted)'),
        reason: 'the driver-recorded entry names the adopted transition',
      );

      fx.dispose();
      exitCode = 0;
    });
  });

  group('bug 1331: refusal classes preserved (SC-5)', () {
    test('B8a: a green-basis drift whose last green evidence POSTDATES the '
        'last reset still refuses subject-drift', () async {
      final fx = await TddFixture.create(featureName: feature);
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

      // Reset (tombstones A1), then a POST-reset certification on a
      // DIFFERENT subject shape — the surviving green evidence now
      // POSTDATES the tombstone and is authoritative again.
      final resetOut = await runner.runCapturing(resetArgs(fx, feature));
      expect(exitCode, 0, reason: resetOut);
      final postResetHash =
          'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';
      await seedGreenEvidenceWithHash(
        fx,
        id,
        postResetHash,
        at: DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 1))
            .toIso8601String(),
      );
      // The re-driven subject passes the test but does not match the
      // post-reset certification.
      await File(fx.testPathOf(id)).writeAsString(subjectDrivenTest(id, desc));
      await File(fx.subjectPathOf(id)).writeAsString(implementedSubject(id));
      await seedRegistry(fx, feature, [recordOf(fx, feature, id, desc)]);

      final out = await runner.runCapturing(makeArgs(fx, id: id));
      expect(
        exitCode,
        isNot(0),
        reason:
            'the post-reset green evidence '
            'is authoritative — the drift refusal stands: $out',
      );
      expect(out, contains('outcome=subject-drift'), reason: out);

      fx.dispose();
      exitCode = 0;
    });

    test('B8b: an identical drift with NO reset tombstone still refuses '
        'subject-drift', () async {
      final fx = await TddFixture.create(featureName: feature);
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
      final stubHash = await subjectHashOf(fx, id);
      await seedGreenEvidenceWithHash(fx, id, stubHash);
      // NO reset: the stale-green hash is authoritative.
      await File(fx.testPathOf(id)).writeAsString(subjectDrivenTest(id, desc));
      await File(fx.subjectPathOf(id)).writeAsString(implementedSubject(id));
      await seedRegistry(fx, feature, [recordOf(fx, feature, id, desc)]);

      final out = await runner.runCapturing(makeArgs(fx, id: id));
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('outcome=subject-drift'), reason: out);

      fx.dispose();
      exitCode = 0;
    });

    test('B8c: the born-green placeholder class still refuses (the #1036 '
        'red-basis refusal is untouched)', () async {
      final fx = await TddFixture.create(featureName: feature);
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

      // The failed-make rewrite class: a non-throwing placeholder body
      // (born-green) — no tombstone, no re-drive: the refusal stands.
      await File(fx.subjectPathOf(id)).writeAsString('''
library;

int a2_value() => 0;
''');

      final out = await runner.runCapturing(makeArgs(fx, id: id));
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('--> fix:'), reason: out);
      expect(out, contains('--re-certify'), reason: out);
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, isNot(contains('## Cycle: $id (green)')));

      fx.dispose();
      exitCode = 0;
    });
  });

  group('bug 1331: the prescription matches reality (SC-6)', () {
    test("B9: doctor's evidence-without-artifact fix line names the adoption "
        'the run actually performs', () async {
      final fx = await TddFixture.create(featureName: feature);
      for (final id in const ['U-001', 'U-002']) {
        await fx.registerBehavior(id: id, description: 'the $id behavior');
        final subject = File(fx.subjectPathOf(id));
        await subject.parent.create(recursive: true);
        await subject.writeAsString('library;\n\nint value() => 42;\n');
        await fx.seedRedEvidence(id);
        await fx.seedGreenEvidence(id);
      }
      await fx.seedRunState(states: {'U-001': 'done', 'U-002': 'done'});
      final runner = CliRunner(exitOnCompletion: false);
      final resetOut = await runner.runCapturing(resetArgs(fx, feature));
      expect(exitCode, 0, reason: resetOut);

      final out = await runner.runCapturing(doctorArgs(fx, feature));

      expect(exitCode, 1, reason: out);
      expect(out, contains('evidence-without-artifact'), reason: out);
      expect(out, contains('zfa tdd run $feature'), reason: out);
      // The prescription names the re-drive adoption mechanics — the
      // run actually completes because make adopts.
      expect(out, contains('adopt'), reason: out);
      final v = envelope(out);
      expect(v['prescription'], 'resume', reason: out);

      fx.dispose();
      exitCode = 0;
    });

    test('B10: the recovery loop composes — reset, doctor prescribes run, '
        "run completes, doctor is healthy again", () async {
      final fx = await TddFixture.create(featureName: feature);
      await fx.writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'U-001',
          description: 'the U-001 behavior',
          traces: 'FR-001',
          state: 'DONE',
          kind: 'unit',
        ),
        (
          id: 'U-002',
          description: 'the U-002 behavior',
          traces: 'FR-001',
          state: 'DONE',
          kind: 'unit',
        ),
      ]);
      for (final id in const ['U-001', 'U-002']) {
        await fx.registerBehavior(id: id, description: 'the $id behavior');
        final subject = File(fx.subjectPathOf(id));
        await subject.parent.create(recursive: true);
        await subject.writeAsString('library;\n\nint value() => 42;\n');
        await fx.seedRedEvidence(id);
        await fx.seedGreenEvidence(id);
      }
      await fx.seedRunState(states: {'U-001': 'done', 'U-002': 'done'});
      final runner = CliRunner(exitOnCompletion: false);

      await runner.runCapturing(resetArgs(fx, feature));
      expect(exitCode, 0);

      final doctor1 = await runner.runCapturing(doctorArgs(fx, feature));
      expect(exitCode, 1, reason: doctor1);
      expect(doctor1, contains('evidence-without-artifact'), reason: doctor1);

      final runOut = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);
      expect(exitCode, 0, reason: runOut);
      expect(runOut, contains('result=complete'), reason: runOut);

      final doctor2 = await runner.runCapturing(doctorArgs(fx, feature));
      expect(exitCode, 0, reason: doctor2);
      final v = envelope(doctor2);
      expect(v['verdict'], 'healthy', reason: doctor2);

      fx.dispose();
      exitCode = 0;
    });
  });
}
