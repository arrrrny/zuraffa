@Tags(['slow'])
// Bug #1345 — the placeholder re-drive deadlock: the documented
// `reset → doctor → run` recovery loop cannot complete for
// acceptance-lane (BOTH-lane) behaviors.
//
// On a tombstoned re-drive the on-disk subject IS the born-green
// compose-pipeline placeholder (the exact bytes `zfa tdd gen` emits — the
// input shape the compose pipeline exists to rewrite), and the acceptance
// test is green-by-construction against the pipeline's own placeholder
// state. The #1331 adoption path deliberately withholds for born-green
// placeholders (the #1036 guard), so make refuses with `subject-drift`,
// the run stops at `<id>:make`, and doctor's `resume` prescription
// dead-ends the same way. The two remediations (#1331 adoption, #1036
// placeholder guard) are individually correct; their intersection has no
// path.
//
// Contract under test (issue #1345, SC-1..SC-4):
//   - B1: the tombstoned acceptance-kind placeholder re-drive make
//     RE-ENTERS the acceptance pipeline at compose/make phase-2 — exit 0,
//     `outcome=adopted-placeholder`, green evidence appended binding the
//     CURRENT post-re-entry subject hash.
//   - B2: the re-entry ran the REAL composition pipeline — the subject on
//     disk is the composed product (references the feature's green unit
//     anchor) and the appended green entry records the `tdd compose`
//     generation step (never a vacuous adoption).
//   - B3: the run driver grades `adopted-placeholder` a terminal make
//     success — the loop advances (green → refactor → done,
//     `result=complete`).
//   - B4: doctor's evidence-without-artifact prescription names the
//     placeholder re-entry (`adopted-placeholder`, issue #1345) and
//     stays `resume`.
//   - B5: a tombstoned NON-acceptance (unit-kind) placeholder re-drive
//     still refuses `subject-drift` (the #1036 refusal stands outside the
//     acceptance lane).
//   - B6: a born-green placeholder with NO reset tombstone still refuses
//     (`subject-drift` — the #1036 guard is untouched outside the
//     re-drive class).
//
// B1/B2 spawn the real `zfa tdd make` (real `dart test` + a real exec
// forwarder for the pipeline's `compose`/`build` subprocesses, SC-021's
// provisioning); B3 drives the CLI in-process against the fake zfa
// binary; B4/B5/B6 mirror the #1331 suite's shapes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

const feature = '090-bug-1345-placeholder-redrive';

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

/// The absolute zuraffa repo root (the real zfa CLI source).
String findZuraffaRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zuraffa')) {
      return dir.path;
    }
    if (dir.path == dir.parent.path) {
      throw StateError('cannot locate the zuraffa repo root');
    }
    dir = dir.parent;
  }
}

/// A real exec forwarder to the repo's bin/zfa.dart (the SC-021
/// pattern): the pipeline's `compose`/`build` subprocesses must run the
/// REAL CLI — the source-resolution tier under `dart test` resolves the
/// test kernel snapshot, not the CLI entrypoint.

/// The gen-shaped THROWING subject stub (`zfa tdd gen A2`): the exact
/// bytes gen emits for the behavior — the compose pipeline's input
/// placeholder (issue #1345's re-drive class).
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

/// The born-green placeholder rewrite class (#1036 rule 3): a
/// non-throwing vacuous body.
String vacuousSubject(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
library;

int $symbol() => 0;
''';
}

/// A GREEN-BY-CONSTRUCTION acceptance test (the #1345 premise): its
/// assertions never exercise the scenario — it passes against ANY
/// compilable subject, including the throwing stub gen re-emits. This is
/// exactly the test class the issue's repro certifies
/// `verify-red -> unexpected-green` on.
String greenByConstructionTest(String id, String description) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// GENERATED TEST — `zfa tdd gen $id` (spec 044-test-tdd-generation).
// behavior_id: $id
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    // The born-green class: structural assertions only — the scenario
    // the behavior names is never exercised.
    expect($symbol, isA<Function>());
  });
}
''';
}

/// The anchor unit test: passes against the implemented unit subject.
/// The symbol is the test-list row's default target (`subject_<id>` —
/// the exact symbol the composition references through the anchor
/// prefix).
String anchorTest(String id, String description) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect($symbol(), equals(42));
  });
}
''';
}

String anchorSubject(String id) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
library;

int $symbol() => 42;
''';
}

/// The anchor's package-import path the composed subject renders
/// (`package:tdd_fixture/<lib-relative path>`).
String anchorSubjectRelative(String id) =>
    '${id.toLowerCase().replaceAll('-', '_')}_subject.dart';

/// A subject-driven test that fails on the throwing stub (the honest red
/// the real verify-red certifies) — the #1331 suite's capture shape: the
/// stub's UnimplementedError is CAUGHT and asserted, so the red carries
/// the Expected/Actual assertion signature.
String subjectDrivenTest(String id, String description) {
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

/// A scenario test whose expected outcome the PLACEHOLDER satisfies
/// (`return 0;` is the declared contract here) but the throwing stub
/// does not: honest certified red against the stub, green against the
/// born-green placeholder — and NOT guard-only, so the #1259
/// vacuous-green gate does not pre-empt the drift check.
String placeholderGreenTest(String id, String description) {
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
    expect(result, equals(0));
  });
}
''';
}

Future<String> subjectHashOf(TddFixture fx, String id) => File(
  fx.subjectPathOf(id),
).readAsBytes().then(sha256.convert).then((h) => h.toString());

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

/// Provision the fixture into a real buildable project (the SC-021
/// pattern): the real pipeline's terminal `build` step runs build_runner
/// + analyze, so the builders must resolve.
Future<void> provisionBuildable(TddFixture fx) async {
  await File(p.join(fx.root.path, 'pubspec.yaml')).writeAsString('''
name: tdd_fixture
environment:
  sdk: ^3.11.0
dependencies:
  zorphy: any
  zorphy_annotation: any
  json_annotation: any
dev_dependencies:
  build_runner: any
  json_serializable: any
  test: ^1.25.0
''');
  final pubGet = await Process.run('dart', [
    'pub',
    'get',
  ], workingDirectory: fx.root.path);
  expect(
    pubGet.exitCode,
    0,
    reason: 'pub get failed:\n${pubGet.stdout}${pubGet.stderr}',
  );
  final binDir = Directory(p.join(fx.root.path, 'fake_bin'));
  await binDir.create(recursive: true);
  final forwarder = p.join(binDir.path, 'zfa');
  await File(forwarder).writeAsString(
    '#!/usr/bin/env bash\nexec '
    '"${Platform.resolvedExecutable}" '
    '"${p.join(findZuraffaRoot(), 'bin', 'zfa.dart')}" '
    '"\$@"\n',
  );
  await Process.run('chmod', ['+x', forwarder]);
}

void main() {
  group('bug 1345: the acceptance placeholder re-drive completes (SC-1)', () {
    test(
      'B1+B2: a tombstoned acceptance-kind placeholder re-drive re-enters '
      'compose — outcome=adopted-placeholder, the REAL composed subject '
      'lands, and the green evidence binds the CURRENT subject hash',
      () async {
        final fx = await TddFixture.create(featureName: feature);
        addTearDown(fx.dispose);
        addTearDown(() => exitCode = 0);
        await provisionBuildable(fx);
        const anchorDesc = 'the U1 unit behavior';
        const acceptDesc = 'the signup flow completes for a registered user';
        const anchorId = 'U1';
        const acceptId = 'A2';

        // The test list: one green unit anchor + the acceptance behavior.
        await fx.seedTestList([
          (
            id: anchorId,
            description: anchorDesc,
            traces: 'FR-001',
            state: 'DONE',
            kind: 'unit',
          ),
          (
            id: acceptId,
            description: acceptDesc,
            traces: 'FR-002',
            state: 'DONE',
            kind: 'acceptance',
          ),
        ]);

        // The completed first drive: the unit anchor is green (its
        // subject exists and its evidence is green), the acceptance
        // behavior carries certified-red evidence (the compose pipeline's
        // precondition).
        await File(fx.testPathOf(anchorId)).parent.create(recursive: true);
        await File(fx.subjectPathOf(anchorId)).parent.create(recursive: true);
        await File(
          fx.testPathOf(anchorId),
        ).writeAsString(anchorTest(anchorId, anchorDesc));
        await File(
          fx.subjectPathOf(anchorId),
        ).writeAsString(anchorSubject(anchorId));
        await File(
          fx.testPathOf(acceptId),
        ).writeAsString(greenByConstructionTest(acceptId, acceptDesc));
        await File(
          fx.subjectPathOf(acceptId),
        ).writeAsString(throwingSubject(acceptId));
        await seedRegistry(fx, feature, [
          recordOf(fx, feature, anchorId, anchorDesc),
          recordOf(fx, feature, acceptId, acceptDesc),
        ]);
        await fx.seedGreenEvidence(anchorId);
        // The acceptance behavior's first drive: certified red against
        // the stub, then the composition pipeline's composed product
        // certified green (its hash is bound; the file reset will
        // delete). The append-only evidence survives reset.
        await fx.seedRedEvidence(acceptId);
        await seedGreenEvidenceWithHash(
          fx,
          acceptId,
          'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        );

        // THE RESET: drops the records, deletes the owned files, and
        // tombstones the behaviors (the documented recovery loop).
        final runner = CliRunner(exitOnCompletion: false);
        final resetOut = await runner.runCapturing(resetArgs(fx, feature));
        expect(exitCode, 0, reason: resetOut);
        expect(
          await File(
            p.join(fx.featureDir, 'tdd', 'journal.json'),
          ).readAsString(),
          contains('"phase": "reset"'),
          reason: 'the reset tombstone is the re-drive class signal',
        );

        // THE RE-DRIVE (what fresh gen + the re-registered ownership
        // produce): the acceptance subject is the born-green
        // compose-pipeline placeholder — the exact bytes gen emits — and
        // the green-by-construction acceptance test PASSES against it.
        // (Reset deleted the owned files and the emptied directories.)
        await File(fx.testPathOf(anchorId)).parent.create(recursive: true);
        await File(fx.subjectPathOf(anchorId)).parent.create(recursive: true);
        await File(
          fx.testPathOf(anchorId),
        ).writeAsString(anchorTest(anchorId, anchorDesc));
        await File(
          fx.subjectPathOf(anchorId),
        ).writeAsString(anchorSubject(anchorId));
        await File(
          fx.testPathOf(acceptId),
        ).writeAsString(greenByConstructionTest(acceptId, acceptDesc));
        await File(
          fx.subjectPathOf(acceptId),
        ).writeAsString(throwingSubject(acceptId));
        await seedRegistry(fx, feature, [
          recordOf(fx, feature, anchorId, anchorDesc),
          recordOf(fx, feature, acceptId, acceptDesc),
        ]);

        // The make: pre-fix this dead-ends with subject-drift (the #1036
        // refusal — the adoption path withholds for placeholders); the
        // documented recovery loop can never complete. Post-fix the
        // placeholder re-drive class RE-ENTERS the acceptance pipeline at
        // compose/make phase-2. The real forwarder drives the pipeline's
        // compose/build subprocesses.
        final out = await runner.runCapturing(
          makeArgs(
            fx,
            id: acceptId,
            zfaBin: p.join(fx.root.path, 'fake_bin', 'zfa'),
          ),
        );
        expect(exitCode, 0, reason: out);
        expect(out, contains('outcome=adopted-placeholder'), reason: out);
        expect(out, contains('issue #1345'), reason: out);

        // B2: the re-entry ran the REAL composition pipeline — the
        // subject on disk is the composed product referencing the green
        // unit anchor, never the vacuous adoption.
        final subject = await File(fx.subjectPathOf(acceptId)).readAsString();
        expect(subject, contains('GENERATED IMPLEMENTATION'), reason: subject);
        expect(subject, contains('zfa tdd compose $acceptId'), reason: subject);
        expect(subject, isNot(contains('UnimplementedError')), reason: subject);
        expect(
          subject,
          contains('package:tdd_fixture/${anchorSubjectRelative(anchorId)}'),
          reason: subject,
        );
        expect(
          subject,
          contains('subject_${anchorId.toLowerCase()}'),
          reason: subject,
        );

        // The green evidence binds the CURRENT (composed) subject hash
        // and records the compose generation step (the audit trail is
        // honest — the certification reflects the pipeline's output).
        // TWO green entries for A2 exist now: the seeded first-drive
        // certification (deadbeef — the composed product reset deleted)
        // and the re-entry's fresh certification.
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(
          RegExp('## Cycle: $acceptId \\(green\\)').allMatches(cycleLog).length,
          2,
          reason: cycleLog,
        );
        final greenSection = cycleLog.substring(
          cycleLog.lastIndexOf('## Cycle: $acceptId (green)'),
        );
        final composedHash = await subjectHashOf(fx, acceptId);
        expect(greenSection, contains('- subject-hash: $composedHash'));
        expect(greenSection, contains('tdd compose $acceptId'), reason: out);
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });

  group('bug 1345: the run loop accepts adopted-placeholder (SC-2)', () {
    test('B3: a make reporting outcome=adopted-placeholder (exit 0, green '
        'evidence written — the real make shape) is a terminal make '
        'success — the loop advances and the run completes', () async {
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
      await seedRegistry(fx, feature, [
        recordOf(fx, feature, 'U-001', 'the U-001 behavior'),
      ]);
      // The placeholder re-drive make: exit 0 with the adopted-placeholder
      // token and the green evidence the real make writes (the fake's
      // shape mirrors the real `zfa tdd make` re-entry outcome).
      await fx.setStepOutcome('make', 'U-001', 'adopt-placeholder');
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
    });
  });

  group('bug 1345: the prescription matches reality (SC-3)', () {
    test("B4: doctor's evidence-without-artifact fix line names the "
        'placeholder re-entry the run actually performs', () async {
      final fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      addTearDown(() => exitCode = 0);
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
      // The prescription names BOTH re-drive mechanics: the #1331
      // adoption AND the #1345 placeholder re-entry.
      expect(out, contains('adopt'), reason: out);
      expect(out, contains('adopted-placeholder'), reason: out);
      expect(out, contains('issue #1345'), reason: out);
      final v = envelope(out);
      expect(v['prescription'], 'resume', reason: out);
    });
  });

  group('bug 1345: refusal classes preserved (SC-4)', () {
    test('B5: a tombstoned NON-acceptance (unit-kind) placeholder re-drive '
        'still refuses subject-drift', () async {
      final fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      addTearDown(() => exitCode = 0);
      const desc = 'returns 0 when invoked with no args';
      const id = 'U1';
      await fx.seedTestList([
        (
          id: id,
          description: desc,
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: id,
        description: desc,
        testContent: placeholderGreenTest(id, desc),
        subjectContent: throwingSubject(id),
      );
      final runner = CliRunner(exitOnCompletion: false);
      final redOut = await runner.runCapturing(verifyRedArgs(fx, id));
      expect(exitCode, 0, reason: redOut);

      // THE RESET (tombstones U1), then the re-drive state: the subject
      // is the born-green placeholder and the test passes against it.
      final resetOut = await runner.runCapturing(resetArgs(fx, feature));
      expect(exitCode, 0, reason: resetOut);
      await File(
        fx.testPathOf(id),
      ).writeAsString(placeholderGreenTest(id, desc));
      await File(fx.subjectPathOf(id)).writeAsString(vacuousSubject(id));
      await seedRegistry(fx, feature, [recordOf(fx, feature, id, desc)]);

      final out = await runner.runCapturing(makeArgs(fx, id: id));
      expect(
        exitCode,
        isNot(0),
        reason:
            'a unit-kind subject implements its own logic — the compose '
            're-entry is the acceptance lane only; the refusal stands: '
            '$out',
      );
      expect(out, contains('outcome=subject-drift'), reason: out);
    });

    test('B6: a born-green placeholder with NO reset tombstone still '
        'refuses (the #1036 red-basis refusal is untouched)', () async {
      final fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      addTearDown(() => exitCode = 0);
      const desc = 'returns 0 when invoked with no args';
      const id = 'A2';
      await fx.seedTestList([
        (
          id: id,
          description: desc,
          traces: 'FR-002',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: id,
        description: desc,
        testContent: placeholderGreenTest(id, desc),
        subjectContent: throwingSubject(id),
      );
      final runner = CliRunner(exitOnCompletion: false);
      final redOut = await runner.runCapturing(verifyRedArgs(fx, id));
      expect(exitCode, 0, reason: redOut);
      // The drifted test passes against the placeholder too (the drift
      // check will be green — the class the refusal governs).
      await File(
        fx.testPathOf(id),
      ).writeAsString(placeholderGreenTest(id, desc));

      // The failed-make rewrite class: a non-throwing placeholder body
      // (born-green) — NO tombstone, no re-drive: the refusal stands.
      await File(fx.subjectPathOf(id)).writeAsString(vacuousSubject(id));

      final out = await runner.runCapturing(makeArgs(fx, id: id));
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('outcome=subject-drift'), reason: out);
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(
        RegExp('## Cycle: $id \\(green\\)').allMatches(cycleLog).length,
        0,
        reason: cycleLog,
      );
    });
  });
}
