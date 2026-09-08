@Tags(['slow'])
// Bug #1331 — `zfa tdd reset <feature>` leaves the half-state: records
// whose paths drifted (relative form resolved against the process CWD,
// or files living at a drifted generated-layout path) are dropped from
// the registry while their files survive on disk, and reset emits NO
// warning and NO outcome validation. The documented recovery loop
// (reset → run) then dead-ends.
//
// Contract under test (issue #1331, SC-1..SC-3):
//   1. Reset deletes ALL owned files: recorded paths normalized against
//      the project root (B1), and generated-shape files whose provenance
//      names a dropped behavior id are recovered from the generated
//      layouts even when the recorded path drifted (B2).
//   2. Reset validates its own outcome: path-drift warnings name the
//      record and the recorded path (B3), the reported deleted count
//      matches the actual deletions, and foreign-but-owned-looking files
//      are reported BY NAME (B4).
//   3. Foreign files are never deleted: unmarked files and files another
//      feature's live registry owns survive untouched (B5 — the #840
//      guarantee holds under the new scan).
//
// Fast tier: no `dart test` subprocesses — reset operates on the
// fixture's files and stores directly.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-bug-1331';
  const otherFeature = '090-bug-1331-other';

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', ...args, '--project', fx.root.path]);
  }

  /// The verdict envelope (`--json`): the LAST stdout line decodes as
  /// the canonical `zuraffa.verdict.v1` object.
  Map<String, dynamic> envelope(String out) {
    final lines = out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return jsonDecode(lines.last) as Map<String, dynamic>;
  }

  /// A generated-shape TEST file for [id] (the provenance header gen
  /// writes — the durable ownership marker).
  String driftedTestContent(String id) =>
      '''
// GENERATED TEST — `zfa tdd gen $id` (spec 044-test-tdd-generation).
// behavior_id: $id
import 'package:test/test.dart';

void main() {
  test('the $id behavior', () {
    expect(1, equals(1));
  });
}
''';

  /// A generated-shape SUBJECT file for [id].
  String driftedSubjectContent(String id) =>
      '''
// GENERATED STUB — `zfa tdd gen $id`.
// behavior_id: $id
library;

int ${id.toLowerCase().replaceAll('-', '_')}_value() => 42;
''';

  /// Overwrite the feature registry with exactly [records].
  Future<void> seedRegistry(List<Map<String, dynamic>> records) async {
    await File(
      p.join(fx.featureDir, 'tdd', 'artifacts.json'),
    ).parent.create(recursive: true);
    await File(
      p.join(fx.featureDir, 'tdd', 'artifacts.json'),
    ).writeAsString(jsonEncode({'feature': feature, 'records': records}));
  }

  Map<String, dynamic> recordOf(
    String id,
    String testPath,
    String subjectPath,
  ) => {
    'behavior_id': id,
    'feature': feature,
    'source_criterion': 'FR-001',
    'test_path': testPath,
    'subject_path': subjectPath,
    'runnable_test_name': '$testPath::$id::the $id behavior',
    'test_ownership': 'created',
    'subject_ownership': 'created',
    'created_at': '2026-08-30T00:00:00.000Z',
  };

  /// The issue's drifted completed feature:
  ///
  /// - U-001 records RELATIVE paths (`test/tdd/…`, `lib/tdd/…`). The
  ///   files exist relative to the PROJECT ROOT — never relative to the
  ///   process CWD the reset runs from (the #1312 abs-vs-rel drift
  ///   class). The file names are distinctive so the raw relative path
  ///   can never accidentally resolve against the test runner's CWD.
  /// - U-002 records paths in a location that no longer exists
  ///   (`gone-flat/`, the old worktree/checkout); its files live at the
  ///   drifted namespaced layout (`test/tdd/<feature>/`,
  ///   `lib/tdd/<feature>/`) carrying the generated-shape provenance
  ///   naming U-002.
  /// - U-003 mirrors U-002's drift, but its drifted test file is
  ///   recorded by ANOTHER feature's live registry (foreign-owned).
  Future<void> seedDriftedFeature() async {
    // U-001: relative recorded paths, files at the project-root-relative
    // locations.
    final u1Test = File(
      p.join(fx.root.path, 'test', 'tdd', 'b1331_u1_test.dart'),
    );
    await u1Test.parent.create(recursive: true);
    await u1Test.writeAsString(driftedTestContent('U-001'));
    final u1Subject = File(
      p.join(fx.root.path, 'lib', 'tdd', 'b1331_u1_subject.dart'),
    );
    await u1Subject.parent.create(recursive: true);
    await u1Subject.writeAsString(driftedSubjectContent('U-001'));

    // U-002: recorded paths gone; drifted generated-shape files at the
    // namespaced layout.
    final u2Test = File(
      p.join(fx.root.path, 'test', 'tdd', feature, 'u2_test.dart'),
    );
    await u2Test.parent.create(recursive: true);
    await u2Test.writeAsString(driftedTestContent('U-002'));
    final u2Subject = File(
      p.join(fx.root.path, 'lib', 'tdd', feature, 'u2_subject.dart'),
    );
    await u2Subject.parent.create(recursive: true);
    await u2Subject.writeAsString(driftedSubjectContent('U-002'));

    // U-003: same drift, but the drifted test file is owned by ANOTHER
    // feature's live registry.
    final u3Test = File(
      p.join(fx.root.path, 'test', 'tdd', feature, 'u3_test.dart'),
    );
    await u3Test.parent.create(recursive: true);
    await u3Test.writeAsString(driftedTestContent('U-003'));

    final otherRegistry = File(
      p.join(fx.root.path, 'specs', otherFeature, 'tdd', 'artifacts.json'),
    );
    await otherRegistry.parent.create(recursive: true);
    await otherRegistry.writeAsString(
      jsonEncode({
        'feature': otherFeature,
        'records': [
          {
            'behavior_id': 'X-001',
            'feature': otherFeature,
            'source_criterion': 'FR-001',
            'test_path': u3Test.path,
            'subject_path': p.join(
              fx.root.path,
              'lib',
              'tdd',
              feature,
              'u3_subject.dart',
            ),
            'runnable_test_name': '${u3Test.path}::X-001::other',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-08-30T00:00:00.000Z',
          },
        ],
      }),
    );

    // An unmarked stray file: no provenance header — never a deletion
    // candidate (the #840 foreign guarantee).
    final stray = File(
      p.join(fx.root.path, 'test', 'tdd', 'b1331_unmarked_stray.dart'),
    );
    await stray.writeAsString('// hand-written, no provenance header\n');

    await seedRegistry([
      recordOf(
        'U-001',
        'test/tdd/b1331_u1_test.dart',
        'lib/tdd/b1331_u1_subject.dart',
      ),
      recordOf(
        'U-002',
        p.join(fx.root.path, 'gone-flat', 'u2_test.dart'),
        p.join(fx.root.path, 'gone-flat', 'u2_subject.dart'),
      ),
      recordOf(
        'U-003',
        p.join(fx.root.path, 'gone-flat', 'u3_test.dart'),
        p.join(fx.root.path, 'gone-flat', 'u3_subject.dart'),
      ),
    ]);
    await fx.seedRunState(
      states: {'U-001': 'done', 'U-002': 'done', 'U-003': 'done'},
    );
    await fx.seedGreenEvidence('U-001');
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
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
      (
        id: 'U-003',
        description: 'the U-003 behavior',
        traces: 'FR-001',
        state: 'DONE',
        kind: 'unit',
      ),
    ]);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('bug 1331: reset deletes ALL owned files (SC-1)', () {
    test(
      'B1: a relative recorded path resolves against the project root — '
      'the file is deleted even though the reset runs from another CWD',
      () async {
        await seedDriftedFeature();

        final out = await runCli(['reset', feature]);

        expect(exitCode, 0, reason: out);
        expect(
          File(
            p.join(fx.root.path, 'test', 'tdd', 'b1331_u1_test.dart'),
          ).existsSync(),
          isFalse,
          reason:
              'the relative recorded test path must resolve against '
              'the project root and the file deleted: $out',
        );
        expect(
          File(
            p.join(fx.root.path, 'lib', 'tdd', 'b1331_u1_subject.dart'),
          ).existsSync(),
          isFalse,
          reason: out,
        );
      },
    );

    test('B2: a path-drifted generated-shape file (recorded path gone, file '
        'at the namespaced layout, provenance names the dropped id) is '
        'deleted by the provenance scan', () async {
      await seedDriftedFeature();

      final out = await runCli(['reset', feature]);

      expect(exitCode, 0, reason: out);
      expect(
        File(
          p.join(fx.root.path, 'test', 'tdd', feature, 'u2_test.dart'),
        ).existsSync(),
        isFalse,
        reason:
            'the drifted generated-shape test naming U-002 must be '
            'deleted: $out',
      );
      expect(
        File(
          p.join(fx.root.path, 'lib', 'tdd', feature, 'u2_subject.dart'),
        ).existsSync(),
        isFalse,
        reason:
            'the drifted generated-shape subject naming U-002 must '
            'be deleted: $out',
      );
    });
  });

  group('bug 1331: reset validates its own outcome (SC-2, SC-3)', () {
    test('B3: path-drift warnings name the record and the recorded path; '
        'the verdict carries path_drift and deleted_files', () async {
      await seedDriftedFeature();

      final out = await runCli(['reset', feature, '--json']);

      expect(exitCode, 0, reason: out);
      // The stdout warns by name (record id + recorded path).
      expect(out, contains('path drift'), reason: out);
      expect(out, contains('U-002'), reason: out);
      expect(out, contains('gone-flat'), reason: out);

      final v = envelope(out);
      expect(v['schema'], 'zuraffa.verdict.v1', reason: out);
      final details = v['details'] as Map<String, dynamic>;
      final pathDrift = (details['path_drift'] as List).cast<String>();
      expect(
        pathDrift.join(' '),
        contains('U-002'),
        reason: 'the drift detail names the dropped record: $out',
      );
      expect(
        pathDrift.join(' '),
        contains('gone-flat'),
        reason: 'the drift detail names the recorded path: $out',
      );
      // U-001's recorded paths exist (normalized) — no drift warning
      // for it.
      expect(
        pathDrift.join(' '),
        isNot(contains('U-001')),
        reason:
            'a record whose normalized paths existed is not '
            'path-drifted: $out',
      );
      final deletedFiles = (details['deleted_files'] as List).cast<String>();
      expect(deletedFiles, hasLength(4), reason: out);
      expect(deletedFiles.join(' '), contains('b1331_u1_test.dart'));
      expect(deletedFiles.join(' '), contains('u2_test.dart'));
    });

    test(
      'B4: the printed will-delete count matches the actual deletions; '
      'a foreign-but-owned-looking file is reported by name and kept',
      () async {
        await seedDriftedFeature();

        final out = await runCli(['reset', feature, '--json']);

        expect(exitCode, 0, reason: out);
        final willDelete = RegExp(
          r'will delete (\d+) owned file\(s\)',
        ).firstMatch(out)?.group(1);
        expect(willDelete, isNotNull, reason: out);

        final v = envelope(out);
        final details = v['details'] as Map<String, dynamic>;
        final deletedFiles = (details['deleted_files'] as List).cast<String>();
        expect(
          deletedFiles.length.toString(),
          willDelete,
          reason:
              'the printed will-delete count must equal the actual '
              'deletions: $out',
        );
        // Zero survivors: every planned deletion landed.
        for (final relative in deletedFiles) {
          expect(
            File(p.join(fx.root.path, relative)).existsSync(),
            isFalse,
            reason: '$relative was reported deleted but survives: $out',
          );
        }

        // The foreign-but-owned-looking file (U-003's drifted test,
        // owned by the other feature's live registry) is reported by
        // name and KEPT.
        final foreignOwnedLooking = (details['foreign_owned_looking'] as List)
            .cast<String>();
        expect(
          foreignOwnedLooking.join(' '),
          contains('u3_test.dart'),
          reason:
              'the foreign-but-owned-looking file is reported by '
              'name: $out',
        );
        expect(
          File(
            p.join(fx.root.path, 'test', 'tdd', feature, 'u3_test.dart'),
          ).existsSync(),
          isTrue,
          reason: 'a file another feature owns is never deleted: $out',
        );
      },
    );

    test('B5: foreign files are never deleted — unmarked strays and another '
        "feature's owned files survive (the #840 guarantee)", () async {
      await seedDriftedFeature();

      final out = await runCli(['reset', feature]);

      expect(exitCode, 0, reason: out);
      expect(
        File(
          p.join(fx.root.path, 'test', 'tdd', 'b1331_unmarked_stray.dart'),
        ).existsSync(),
        isTrue,
        reason: 'an unmarked stray is foreign — never deleted: $out',
      );
      expect(
        File(
          p.join(fx.root.path, 'test', 'tdd', feature, 'u3_test.dart'),
        ).existsSync(),
        isTrue,
        reason: out,
      );
      expect(
        out,
        contains('will keep'),
        reason: 'the foreign-kept count is still announced: $out',
      );
      // The registry and run-state are still dropped (the reset core
      // semantics are unchanged).
      expect(
        File(p.join(fx.featureDir, 'tdd', 'artifacts.json')).existsSync(),
        isFalse,
        reason: out,
      );
      expect(
        File(p.join(fx.featureDir, 'tdd', 'run-state.json')).existsSync(),
        isFalse,
        reason: out,
      );
    });
  });
}
