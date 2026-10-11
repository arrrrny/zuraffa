@Tags(['slow'])
// Bug #1397 — tdd gen's ownership gate misfires on registry path-form
// mismatch, and doctor reports the mixed-form registry healthy with no
// remedy.
//
// Issue state: a registry records the SAME feature's artifacts in mixed
// forms — machine-absolute for some behaviors (`/home/z/my-project/…`,
// the fixture's a3/a4/a6/a7 rows) and project-relative for others
// (`test/tdd/<feature>/…`, the a5 row). A repeat `zfa tdd gen` of a
// relative-recorded behavior compares string FORMS, not resolved paths:
// `p.equals` resolves the caller's relative form against the process CWD
// (never the project root), so the gate reports an ownership conflict for
// files that are the same — while `zfa tdd doctor` reports no drift at
// all (its checks never look at the recorded path form), so the
// prescribed recovery cannot even see the problem.
//
// Contract under test:
// 1. The ownership gate resolves both sides against the project root:
//    mixed-form records of the SAME files reuse, never conflict.
// 2. The registry persists the portable project-relative POSIX form (no
//    machine-specific absolute path survives a write), so committed
//    registries stay portable.
// 3. `zfa tdd doctor` flags machine-absolute recorded paths as drift and
//    prescribes `zfa tdd migrate-paths --feature <feature>` (issue #1573:
//    the flag form the command actually parses — a positional slug is
//    silently discarded) — and the prescribed migration actually repairs
//    the drift (doctor returns healthy).
// 4. `zfa tdd migrate-paths` rewrites the recorded FORM (absolute →
//    project-relative) of already-namespaced records without moving any
//    file, fails honestly when a recorded artifact is missing, and is
//    idempotent.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmpDir;

  const feature = '100-feature-one';

  /// Machine-absolute recorded form (the issue's a3/a4 shape) for a1.
  late String absTestPath;
  late String absSubjectPath;

  /// Portable recorded form for the same files.
  const relTestPath = 'test/tdd/100-feature-one/a1_test.dart';
  const relSubjectPath = 'lib/tdd/100-feature-one/a1_subject.dart';

  String registryJson(List<Map<String, String>> paths) => jsonEncode({
    'feature': feature,
    'records': [
      {
        'behavior_id': 'A1',
        'feature': feature,
        'source_criterion': 'FR-007',
        'test_path': paths[0]['test'],
        'subject_path': paths[0]['subject'],
        'runnable_test_name':
            '${paths[0]['test']}::A1::returns 42 when invoked with no args',
        'test_ownership': 'created',
        'subject_ownership': 'created',
        'created_at': '2026-09-01T00:00:00.000Z',
      },
    ],
  });

  List<String> genArgs(String id, {String? featureName}) => [
    'tdd',
    'gen',
    '--project',
    tmpDir.path,
    if (featureName != null) ...['--feature', featureName],
    id,
  ];

  List<String> migrateArgs([List<String> extra = const <String>[]]) => [
    'tdd',
    'migrate-paths',
    '--project',
    tmpDir.path,
    ...extra,
  ];

  List<String> doctorArgs() => [
    'tdd',
    'doctor',
    feature,
    '--project',
    tmpDir.path,
  ];

  /// Seed specs/<feature>/{spec.md,tdd/test-list.md} — the minimum a
  /// unit-lane gen needs to resolve behavior A1.
  Future<void> seedFeature() async {
    final specDir = Directory(p.join(tmpDir.path, 'specs', feature));
    await specDir.create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString('''
# Spec for $feature

## Functional Requirements

- **FR-007**: returns 42 when invoked with no args
''');
    final tddDir = Directory(p.join(specDir.path, 'tdd'));
    await tddDir.create(recursive: true);
    await File(p.join(tddDir.path, 'test-list.md')).writeAsString('''
# Test List for $feature

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| A1 | returns 42 when invoked with no args | FR-007 | unit | PENDING | sampleSubject |
''');
  }

  /// Create the a1 pair at the namespaced paths with plain content (no
  /// imports — the pair must pass doctor's import/symbol checks).
  Future<void> seedArtifacts() async {
    for (final rel in [relTestPath, relSubjectPath]) {
      final file = File(p.join(tmpDir.path, rel));
      await file.parent.create(recursive: true);
      await file.writeAsString('// prior artifact\n');
    }
  }

  Future<void> writeRegistry(String raw) async {
    final file = File(
      p.join(tmpDir.path, 'specs', feature, 'tdd', 'artifacts.json'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(raw);
  }

  Map<String, dynamic> readRegistryRecords() {
    final raw = File(
      p.join(tmpDir.path, 'specs', feature, 'tdd', 'artifacts.json'),
    ).readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['records'] as List).single as Map<String, dynamic>;
  }

  /// The last non-empty stdout line — the recovery commands' JSON verdict
  /// contract (bug #840).
  Map<String, dynamic> verdict(String out) {
    final lines = out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return jsonDecode(lines.last) as Map<String, dynamic>;
  }

  /// The `--> fix:` line's payload, for assertions that must not be
  /// sensitive to trailing explanation text.
  String fixLine(String out) => out
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.startsWith('--> fix:'))
      .substring('--> fix:'.length)
      .trim();

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1397_path_form_test_');
    absTestPath = p.join(tmpDir.path, relTestPath);
    absSubjectPath = p.join(tmpDir.path, relSubjectPath);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('Bug #1397 — gen ownership gate across path forms', () {
    test('re-gen of a relative-recorded behavior succeeds instead of '
        'refusing an ownership conflict', () async {
      await seedFeature();
      await seedArtifacts();
      // The issue's a5 shape: the prior record is the PORTABLE relative
      // form while gen computes the machine-absolute form of the same
      // files.
      await writeRegistry(
        registryJson([
          {'test': relTestPath, 'subject': relSubjectPath},
        ]),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        genArgs('A1', featureName: feature),
      );

      expect(
        out,
        contains('reused/reused'),
        reason:
            'the gate resolves both path forms against the project root; '
            'the same files must reuse, not conflict (issue #1397)',
      );
      expect(out.toLowerCase(), isNot(contains('ownership conflict')));
    });
  });

  group('Bug #1397 — zfa tdd doctor path-form drift', () {
    test(
      'flags machine-absolute records and prescribes migrate-paths',
      () async {
        await seedArtifacts();
        await writeRegistry(
          registryJson([
            {'test': absTestPath, 'subject': absSubjectPath},
          ]),
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(doctorArgs());

        final v = verdict(out);
        expect(v['verdict'], 'drift');
        expect(v['prescription'], 'migrate');
        expect(v['fix'], contains('zfa tdd migrate-paths --feature $feature'));
        expect(
          (v['drifts'] as List).join(' '),
          contains('A1'),
          reason: 'the drift names the offending behavior',
        );
        expect(
          fixLine(out),
          contains('zfa tdd migrate-paths --feature $feature'),
        );
      },
    );

    test(
      'the prescribed migration repairs the drift (doctor -> healthy)',
      () async {
        await seedArtifacts();
        await writeRegistry(
          registryJson([
            {'test': absTestPath, 'subject': absSubjectPath},
          ]),
        );
        final runner = CliRunner(exitOnCompletion: false);

        await runner.runCapturing(doctorArgs()); // drift + prescription
        final migrateOut = await runner.runCapturing(
          migrateArgs(['--feature', feature]),
        );
        expect(migrateOut, contains('migrated=1'));

        final out = await runner.runCapturing(doctorArgs());
        final v = verdict(out);
        expect(v['verdict'], 'healthy');
        expect(v['prescription'], 'none');
      },
    );

    test('a portable (project-relative) registry is healthy', () async {
      await seedArtifacts();
      await writeRegistry(
        registryJson([
          {'test': relTestPath, 'subject': relSubjectPath},
        ]),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(doctorArgs());

      final v = verdict(out);
      expect(v['verdict'], 'healthy');
      expect(v['prescription'], 'none');
    });

    test(
      'a relocated registry is prescribed migrate-paths, not reset',
      () async {
        // The shipped fixture's shape: machine-absolute paths from a project
        // root that does not exist on this machine, while the artifacts sit
        // at the same project-relative locations under the current root.
        // That is path-FORM drift (recoverable by rewriting the recorded
        // strings), not a missing artifact — prescribing `reset` would drop
        // certified behaviors over a path form.
        await seedArtifacts();
        const foreignRoot = '/home/z/my-project/zuraffa';
        await writeRegistry(
          registryJson([
            {
              'test': '$foreignRoot/test/tdd/100-feature-one/a1_test.dart',
              'subject': '$foreignRoot/lib/tdd/100-feature-one/a1_subject.dart',
            },
          ]),
        );
        final runner = CliRunner(exitOnCompletion: false);

        final out = await runner.runCapturing(doctorArgs());
        final v = verdict(out);
        expect(v['verdict'], 'drift');
        expect(
          v['prescription'],
          'migrate',
          reason:
              'a relocatable record is form drift — the migration repairs '
              'it; reset would drop the certified behavior',
        );
        expect(
          fixLine(out),
          contains('zfa tdd migrate-paths --feature $feature'),
        );

        // The prescription closes the loop: the migration heals the
        // relocated registry and doctor returns healthy.
        await runner.runCapturing(migrateArgs(['--feature', feature]));
        final healed = await runner.runCapturing(doctorArgs());
        expect(verdict(healed)['verdict'], 'healthy');
      },
    );
  });

  group('Bug #1397 — zfa tdd migrate-paths form rewrite', () {
    test('rewrites machine-absolute namespaced records to the portable '
        'form without touching any file', () async {
      await seedArtifacts();
      await writeRegistry(
        registryJson([
          {'test': absTestPath, 'subject': absSubjectPath},
        ]),
      );
      final testSha = File(absTestPath).readAsStringSync();
      final subjectSha = File(absSubjectPath).readAsStringSync();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        migrateArgs(['--feature', feature]),
      );

      expect(out, contains('migrated=1'));
      final stored = readRegistryRecords();
      expect(stored['test_path'], relTestPath);
      expect(stored['subject_path'], relSubjectPath);
      expect(
        stored['runnable_test_name'],
        '$relTestPath::A1::returns 42 when invoked with no args',
      );
      // A form rewrite moves nothing: both files are byte-for-byte
      // unchanged.
      expect(File(absTestPath).readAsStringSync(), testSha);
      expect(File(absSubjectPath).readAsStringSync(), subjectSha);
    });

    test('dry-run reports the form rewrite and writes nothing', () async {
      await seedArtifacts();
      await writeRegistry(
        registryJson([
          {'test': absTestPath, 'subject': absSubjectPath},
        ]),
      );
      final before = File(
        p.join(tmpDir.path, 'specs', feature, 'tdd', 'artifacts.json'),
      ).readAsStringSync();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        migrateArgs(['--feature', feature, '--dry-run']),
      );

      expect(out, contains('migrated=1'));
      expect(out, contains('dry-run — no changes were written.'));
      expect(
        File(
          p.join(tmpDir.path, 'specs', feature, 'tdd', 'artifacts.json'),
        ).readAsStringSync(),
        before,
      );
    });

    test('a recorded artifact missing from disk is reported and left '
        'unchanged (fail-honest)', () async {
      // Only the subject exists; the recorded test file is missing.
      final subjectFile = File(absSubjectPath);
      await subjectFile.parent.create(recursive: true);
      await subjectFile.writeAsString('// prior subject\n');
      await writeRegistry(
        registryJson([
          {'test': absTestPath, 'subject': absSubjectPath},
        ]),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        migrateArgs(['--feature', feature]),
      );

      expect(out, contains('MISSING for behavior "A1"'));
      expect(out, contains('missing=1'));
      expect(
        readRegistryRecords()['test_path'],
        absTestPath,
        reason: 'a missing artifact is reported, never silently rewritten',
      );
    });

    test('is idempotent: a second run rewrites nothing', () async {
      await seedArtifacts();
      await writeRegistry(
        registryJson([
          {'test': absTestPath, 'subject': absSubjectPath},
        ]),
      );
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(migrateArgs(['--feature', feature]));

      final out = await runner.runCapturing(
        migrateArgs(['--feature', feature]),
      );
      expect(out, contains('migrated=0'));
      expect(readRegistryRecords()['test_path'], relTestPath);
    });

    test(
      'a relocated registry (foreign machine-absolute paths, artifacts '
      'present under the project root) is repaired to the portable form',
      () async {
        // The shipped fixture's shape (issue #1397 requirement 3): the
        // registry was committed with machine-absolute paths authored on a
        // machine whose project root no longer exists here
        // (`/home/z/my-project/zuraffa`), while the artifacts themselves sit
        // at the same project-relative locations under the current root. The
        // migration must find the relocated files and rewrite the recorded
        // form — not report a missing artifact and leave a dead absolute
        // record that doctor keeps flagging forever.
        await seedArtifacts();
        const foreignRoot = '/home/z/my-project/zuraffa';
        final foreignTestPath =
            '$foreignRoot/test/tdd/100-feature-one/a1_test.dart';
        final foreignSubjectPath =
            '$foreignRoot/lib/tdd/100-feature-one/a1_subject.dart';
        await writeRegistry(
          registryJson([
            {'test': foreignTestPath, 'subject': foreignSubjectPath},
          ]),
        );
        final cycleLog = File(
          p.join(tmpDir.path, 'specs', feature, 'tdd', 'cycle-log.md'),
        );
        await cycleLog.parent.create(recursive: true);
        await cycleLog.writeAsString('''
# Cycle Log

## Cycle 1

- behavior: A1
- test: $foreignTestPath
- command: dart test $foreignTestPath
''');
        final testSha = File(absTestPath).readAsStringSync();
        final subjectSha = File(absSubjectPath).readAsStringSync();

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          migrateArgs(['--feature', feature]),
        );

        expect(out, contains('migrated=1'));
        expect(out, contains('missing=0'));
        final stored = readRegistryRecords();
        expect(stored['test_path'], relTestPath);
        expect(stored['subject_path'], relSubjectPath);
        expect(
          stored['runnable_test_name'],
          '$relTestPath::A1::returns 42 when invoked with no args',
        );
        // The cycle-log's foreign absolute evidence is rewritten to the
        // portable relative form, never to this machine's absolute paths.
        final rewritten = cycleLog.readAsStringSync();
        expect(rewritten, isNot(contains(foreignRoot)));
        expect(rewritten, contains('- test: $relTestPath'));
        expect(rewritten, contains('dart test $relTestPath'));
        // A relocated repair still moves nothing.
        expect(File(absTestPath).readAsStringSync(), testSha);
        expect(File(absSubjectPath).readAsStringSync(), subjectSha);
      },
    );
  });
}
