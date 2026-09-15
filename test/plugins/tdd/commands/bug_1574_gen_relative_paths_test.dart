@Tags(['e2e'])
// No `slow` tag: this suite is a fast in-process fixture test (CliRunner
// spawns no subprocesses) so the default CI tier runs the #1574 guard on
// every build — the same reasoning as bug_1573_doctor_migrate_prescription_test.
// Bug #1574 — tdd gen still records machine-absolute test_path/subject_path
// while the run driver records the relative form — 11 of 18 committed
// registries are absolute (#1397's corruption is still being written).
//
// Issue state: gen_command.dart composes the record's artifact paths straight
// from the machine-absolute `cwd` and embeds them in the record's
// runnable_test_name, so gen's emitted record carries `/…` forms. In the
// specs lane the #1397 canonicalization net relativizes the PERSISTED form,
// but in the bug extension's documented `.specify/bugs/<slug>` lane the
// registry's project-root heuristic resolves the root to `<root>/.specify/bugs`
// and the machine-absolute form survives the write — new absolute records are
// still being written today.
//
// Contract under test:
// 1. The RECORD gen builds (persisted form + stdout verdict lines) carries
//    the portable project-relative POSIX form — `test/…` / `lib/…`, never
//    `/…` — in BOTH lanes (the run driver's recorded shape, af40f686b).
// 2. Re-gen of a behavior whose prior record is the run driver's relative
//    form reuses without an ownership conflict in the bug lane (acceptance 3).
// 3. Every committed registry records relative forms (acceptance 2 — the
//    migrated data stays migrated).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmpDir;

  const feature = '100-feature-one';

  const relTestPath = 'test/tdd/100-feature-one/a1_test.dart';
  const relSubjectPath = 'lib/tdd/100-feature-one/a1_subject.dart';

  /// Seeds `specs/<feature>` (specs lane) or `.specify/bugs/<feature>`
  /// (bug lane) with the minimum a unit-lane gen needs to resolve A1.
  Future<Directory> seedFeature(Directory root, {required bool bugLane}) async {
    // Issue #1528: gen's entry preflight is a SILENT NO-OP when the TDD
    // profile exists (no writes at all — no pubspec read, no baseline
    // writes) — seed it so these tests keep pinning gen's own behavior
    // in a pubspec-less fixture (same pattern as
    // bug_1518_gen_command_seam_test.dart).
    final memoryDir = Directory(p.join(root.path, '.specify', 'memory'));
    memoryDir.createSync(recursive: true);
    File(p.join(memoryDir.path, 'tdd-profile.md')).writeAsStringSync('''
# TDD Profile — fixture

## Commands

- Single test: `dart test {file} --plain-name "{name}"`
- Full suite: `dart test`

## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test {file} --plain-name "{name}"'
suite: 'dart test'
file: 'dart test {file}'
coverage: 'dart test --coverage'
```
''');
    final specDir = bugLane
        ? Directory(p.join(root.path, '.specify', 'bugs', feature))
        : Directory(p.join(root.path, 'specs', feature));
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
    return specDir;
  }

  List<String> genArgs(String featureRef) => [
    'tdd',
    'gen',
    '--project',
    tmpDir.path,
    '--feature',
    featureRef,
    'A1',
  ];

  Map<String, dynamic> readFirstRecord(File registryFile) {
    final decoded =
        jsonDecode(registryFile.readAsStringSync()) as Map<String, dynamic>;
    final records = decoded['records'] as List;
    expect(records, isNotEmpty, reason: 'gen must append its record');
    return records.first as Map<String, dynamic>;
  }

  /// The stdout record block gen prints (behavior_id / test_path / …).
  Map<String, String> stdoutRecord(String out) {
    final record = <String, String>{};
    for (final line in out.split('\n')) {
      final match = RegExp('^([a-z_]+): (.*)\$').firstMatch(line.trim());
      if (match != null) {
        final key = match.group(1)!;
        if (const {
          'behavior_id',
          'source_criterion',
          'kind',
          'test_path',
          'subject_path',
          'runnable_test_name',
          'ownership',
        }.contains(key)) {
          record[key] = match.group(2)!;
        }
      }
    }
    return record;
  }

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1574_gen_rel_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('Bug #1574 — gen records the portable relative form', () {
    test('specs lane: fresh gen persists relative record paths', () async {
      await seedFeature(tmpDir, bugLane: false);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs(feature));

      expect(out, contains('created/created'), reason: out);
      final stored = readFirstRecord(
        File(p.join(tmpDir.path, 'specs', feature, 'tdd', 'artifacts.json')),
      );
      expect(
        stored['test_path'],
        relTestPath,
        reason:
            'the registry record is the portable project-relative form '
            '(issue #1574)',
      );
      expect(stored['subject_path'], relSubjectPath);
      expect(
        stored['runnable_test_name'],
        startsWith('$relTestPath::A1::'),
        reason: 'the runnable name is built from the relative form',
      );
    });

    test(
      'bug lane: fresh gen persists relative record paths (the live leak)',
      () async {
        await seedFeature(tmpDir, bugLane: true);

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          genArgs('.specify/bugs/$feature'),
        );

        expect(out, contains('created/created'), reason: out);
        final stored = readFirstRecord(
          File(
            p.join(
              tmpDir.path,
              '.specify',
              'bugs',
              feature,
              'tdd',
              'artifacts.json',
            ),
          ),
        );
        expect(
          stored['test_path'],
          relTestPath,
          reason:
              'a .specify/bugs/<slug> feature records the same relative '
              'form — the machine-absolute form must not survive the write '
              '(issue #1574: the corruption is still being written)',
        );
        expect(stored['subject_path'], relSubjectPath);
        expect(stored['runnable_test_name'], startsWith('$relTestPath::A1::'));
      },
    );
  });

  group('Bug #1574 — gen emits the relative form on stdout', () {
    for (final (label, bugLane) in [
      ('specs lane', false),
      ('bug lane', true),
    ]) {
      test('$label: the emitted record carries relative paths', () async {
        await seedFeature(tmpDir, bugLane: bugLane);

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          genArgs(bugLane ? '.specify/bugs/$feature' : feature),
        );

        final record = stdoutRecord(out);
        expect(record['test_path'], relTestPath, reason: out);
        expect(record['subject_path'], relSubjectPath, reason: out);
        expect(
          record['runnable_test_name'],
          startsWith('$relTestPath::A1::'),
          reason: out,
        );
      });
    }
  });

  group('Bug #1574 — re-gen reuse against the run driver\'s relative form', () {
    test(
      'bug lane: a relative prior record reuses without an ownership conflict',
      () async {
        final specDir = await seedFeature(tmpDir, bugLane: true);
        // The pair exists on disk and the registry (written by the run
        // driver's relative form) owns it — the exact state a `zfa tdd run`
        // leaves behind for a .specify/bugs/<slug> feature.
        for (final rel in [relTestPath, relSubjectPath]) {
          final file = File(p.join(tmpDir.path, rel));
          await file.parent.create(recursive: true);
          await file.writeAsString('// prior artifact\n');
        }
        final registryFile = File(
          p.join(specDir.path, 'tdd', 'artifacts.json'),
        );
        await registryFile.parent.create(recursive: true);
        await registryFile.writeAsString(
          jsonEncode({
            'feature': feature,
            'records': [
              {
                'behavior_id': 'A1',
                'feature': feature,
                'source_criterion': 'FR-007',
                'test_path': relTestPath,
                'subject_path': relSubjectPath,
                'runnable_test_name':
                    '$relTestPath::A1::returns 42 when invoked with no args',
                'test_ownership': 'created',
                'subject_ownership': 'created',
                'created_at': '2026-09-13T00:00:00.000Z',
              },
            ],
          }),
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          genArgs('.specify/bugs/$feature'),
        );

        expect(
          out,
          contains('reused/reused'),
          reason:
              'the run driver records the relative form; gen must reuse the '
              'same files, never refuse an ownership conflict (issue #1574 '
              'acceptance 3). Output was: $out',
        );
        expect(out.toLowerCase(), isNot(contains('ownership conflict')));
      },
    );
  });

  group('Bug #1574 — committed registries stay migrated (acceptance 2)', () {
    test('every tracked artifacts.json records relative artifact paths', () {
      final repoRoot = Directory.current.path;
      final tracked = <String>[];
      final ProcessResult probe;
      try {
        probe = Process.runSync('git', [
          'ls-files',
          '*.json',
        ], workingDirectory: repoRoot);
      } on ProcessException catch (error) {
        // A bare ProcessException (git absent) would bury the census's own
        // reason — keep the failure legible instead.
        fail('the census needs `git ls-files` to list the registries: $error');
      }
      for (final line in (probe.stdout as String).split('\n')) {
        if (line.trim().endsWith('artifacts.json')) tracked.add(line.trim());
      }
      expect(tracked, isNotEmpty, reason: 'the census must see the registries');

      final absoluteRecords = <String>[];
      for (final rel in tracked) {
        final file = File(p.join(repoRoot, rel));
        if (!file.existsSync()) continue;
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is! Map<String, dynamic>) continue;
        final records = decoded['records'];
        if (records is! List) continue;
        for (final record in records) {
          if (record is! Map<String, dynamic>) continue;
          for (final key in ['test_path', 'subject_path']) {
            final value = record[key];
            if (value is String && value.startsWith('/')) {
              absoluteRecords.add('$rel (${record['behavior_id']}: $key)');
            }
          }
          // The issue's drifted record embeds the machine-absolute prefix a
          // third time, in runnable_test_name's first `::` segment — a
          // regression that reintroduces it ONLY there must not slip past
          // this census unnoticed.
          final runnable = record['runnable_test_name'];
          if (runnable is String) {
            final firstSegment = runnable.split('::').first;
            if (firstSegment.contains('/') && firstSegment.startsWith('/')) {
              absoluteRecords.add(
                '$rel (${record['behavior_id']}: runnable_test_name)',
              );
            }
          }
        }
      }
      expect(
        absoluteRecords,
        isEmpty,
        reason:
            'committed registries must carry the portable relative form — '
            'machine-absolute paths only resolve on one machine (issue '
            '#1574 acceptance 2). Offenders: ${absoluteRecords.join(', ')}',
      );
    });
  });
}
