@Tags(['slow'])
// Bug #827 — per-feature TDD artifact namespacing: end the test/tdd ownership
// collision.
//
// Root cause: gen constructs feature-agnostic paths (test/tdd/<id>_test.dart,
// lib/tdd/<id>_subject.dart) while the artifact registry is per-feature. When
// feature-2 gens a behavior after feature-1 completed, feature-1 owns the flat
// file, feature-2's registry has no record for it, and preflight correctly
// refuses — two features can never coexist in the flat layout.
//
// These tests drive the fix through the public CLI surface (`zfa tdd gen`,
// `zfa tdd migrate-paths`): artifacts must be namespaced by feature-slug
// (test/tdd/<feature-slug>/, lib/tdd/<feature-slug>/), the registry must record
// the namespaced paths, the guardrail must keep working against them, and an
// explicit migration must move legacy flat projects over without breaking them.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';

void main() {
  late Directory tmpDir;

  List<String> genArgs(String id, {String? feature}) => [
    'tdd',
    'gen',
    '--project',
    tmpDir.path,
    if (feature != null) ...['--feature', feature],
    id,
  ];

  List<String> migrateArgs([List<String> extra = const <String>[]]) => [
    'tdd',
    'migrate-paths',
    '--project',
    tmpDir.path,
    ...extra,
  ];

  /// Seed one feature with one unit behavior row in its test list.
  Future<void> seedFeature(
    String featureName, {
    String behaviorId = 'A1',
    String description = 'returns 42 when invoked with no args',
    String target = 'sampleSubject',
  }) async {
    final specDir = Directory(p.join(tmpDir.path, 'specs', featureName));
    await specDir.create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString('''
# Spec for $featureName

## Functional Requirements

- **FR-007**: $description
''');
    final tddDir = Directory(p.join(specDir.path, 'tdd'));
    await tddDir.create(recursive: true);
    await File(p.join(tddDir.path, 'test-list.md')).writeAsString('''
# Test List for $featureName

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| $behaviorId | $description | FR-007 | unit | PENDING | $target |
''');
  }

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('gen_namespacing_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('Bug #827 — namespaced artifact paths', () {
    test(
      'feature-1 then feature-2 with the same behavior id: both gens succeed '
      'and artifacts live under per-feature directories',
      () async {
        await seedFeature('100-feature-one');
        await seedFeature('200-feature-two');

        final runner = CliRunner(exitOnCompletion: false);

        // Feature-1 gen: writes test/tdd/100-feature-one/a1_test.dart.
        final out1 = await runner.runCapturing(
          genArgs('A1', feature: '100-feature-one'),
        );
        expect(
          out1,
          contains('test/tdd/100-feature-one/a1_test.dart'),
          reason: 'the printed test_path must be namespaced by feature-slug',
        );
        expect(
          out1,
          contains('lib/tdd/100-feature-one/a1_subject.dart'),
          reason: 'the printed subject_path must be namespaced by feature-slug',
        );
        expect(
          File(
            p.join(
              tmpDir.path,
              'test',
              'tdd',
              '100-feature-one',
              'a1_test.dart',
            ),
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            p.join(
              tmpDir.path,
              'lib',
              'tdd',
              '100-feature-one',
              'a1_subject.dart',
            ),
          ).existsSync(),
          isTrue,
        );

        // Feature-2 gen for the SAME behavior id: must NOT hit feature-1's
        // flat artifact. Pre-fix this exits non-zero with an ownership
        // conflict (the RED evidence for bug #827).
        final out2 = await runner.runCapturing(
          genArgs('A1', feature: '200-feature-two'),
        );
        expect(
          out2,
          contains('test/tdd/200-feature-two/a1_test.dart'),
          reason: 'feature-2 must own its own namespaced test artifact',
        );
        expect(
          File(
            p.join(
              tmpDir.path,
              'test',
              'tdd',
              '200-feature-two',
              'a1_test.dart',
            ),
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            p.join(
              tmpDir.path,
              'lib',
              'tdd',
              '200-feature-two',
              'a1_subject.dart',
            ),
          ).existsSync(),
          isTrue,
        );

        // Both features' registries recorded the namespaced paths.
        for (final feature in const ['100-feature-one', '200-feature-two']) {
          final registry = File(
            p.join(tmpDir.path, 'specs', feature, 'tdd', 'artifacts.json'),
          );
          expect(registry.existsSync(), isTrue);
          final raw = registry.readAsStringSync();
          expect(raw, contains('test/tdd/$feature/a1_test.dart'));
          expect(raw, contains('lib/tdd/$feature/a1_subject.dart'));
          expect(
            raw,
            contains(
              'test/tdd/$feature/a1_test.dart::A1::'
              'returns 42 when invoked with no args',
            ),
            reason: 'runnable_test_name must carry the namespaced path',
          );
        }
      },
    );

    test('the generated test imports its namespaced sibling subject via a '
        'relative path that resolves on disk', () async {
      await seedFeature('100-feature-one');
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('A1', feature: '100-feature-one'));

      final testFile = File(
        p.join(tmpDir.path, 'test', 'tdd', '100-feature-one', 'a1_test.dart'),
      );
      final content = testFile.readAsStringSync();
      expect(
        content,
        contains("import '../../../lib/tdd/100-feature-one/a1_subject.dart'"),
        reason:
            'the relative import must climb out of test/tdd/<feature>/ and '
            'land on the namespaced subject sibling',
      );
    });

    test(
      'repeat gen for the same behavior is a namespaced no-op (reused/reused)',
      () async {
        await seedFeature('100-feature-one');
        final runner = CliRunner(exitOnCompletion: false);
        final out1 = await runner.runCapturing(
          genArgs('A1', feature: '100-feature-one'),
        );
        expect(out1, contains('created/created'));
        final out2 = await runner.runCapturing(
          genArgs('A1', feature: '100-feature-one'),
        );
        expect(out2, contains('reused/reused'));
      },
    );

    test(
      'ownership guardrail still refuses a foreign file at a namespaced path',
      () async {
        await seedFeature('100-feature-one');
        // Hand-write the file at the NAMESPACED path before gen runs.
        final foreign = File(
          p.join(tmpDir.path, 'test', 'tdd', '100-feature-one', 'a1_test.dart'),
        );
        await foreign.parent.create(recursive: true);
        await foreign.writeAsString('// user-authored');

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          genArgs('A1', feature: '100-feature-one'),
        );
        expect(out.toLowerCase(), contains('ownership conflict'));
        expect(
          foreign.readAsStringSync(),
          '// user-authored',
          reason: 'the foreign file must be left byte-for-byte untouched',
        );
      },
    );
  });

  group('Bug #827 — zfa tdd migrate-paths (legacy flat-layout migration)', () {
    test(
      'moves recorded flat artifacts under the feature dirs and rewrites the '
      'registry (paths + runnable name)',
      () async {
        await seedFeature('100-feature-one');
        // Simulate the LEGACY state: gen (pre-fix) wrote flat artifacts and
        // recorded their flat paths.
        final testFile = File(
          p.join(tmpDir.path, 'test', 'tdd', 'a1_test.dart'),
        );
        await testFile.parent.create(recursive: true);
        await testFile.writeAsString('// legacy flat test');
        final subjectFile = File(
          p.join(tmpDir.path, 'lib', 'tdd', 'a1_subject.dart'),
        );
        await subjectFile.parent.create(recursive: true);
        await subjectFile.writeAsString('// legacy flat subject');
        File(
            p.join(
              tmpDir.path,
              'specs',
              '100-feature-one',
              'tdd',
              'artifacts.json',
            ),
          )
          ..parent.create(recursive: true)
          ..writeAsStringSync('''
{
  "feature": "100-feature-one",
  "records": [
    {
      "behavior_id": "A1",
      "feature": "100-feature-one",
      "source_criterion": "FR-007",
      "test_path": "test/tdd/a1_test.dart",
      "subject_path": "lib/tdd/a1_subject.dart",
      "runnable_test_name": "test/tdd/a1_test.dart::A1::returns 42 when invoked with no args",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-01T00:00:00.000Z"
    }
  ]
}
''');

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(migrateArgs());
        expect(out, contains('migrate-paths'));
        expect(out, contains('migrated=1'));

        // Files moved.
        expect(testFile.existsSync(), isFalse);
        expect(subjectFile.existsSync(), isFalse);
        expect(
          File(
            p.join(
              tmpDir.path,
              'test',
              'tdd',
              '100-feature-one',
              'a1_test.dart',
            ),
          ).readAsStringSync(),
          '// legacy flat test',
        );
        expect(
          File(
            p.join(
              tmpDir.path,
              'lib',
              'tdd',
              '100-feature-one',
              'a1_subject.dart',
            ),
          ).readAsStringSync(),
          '// legacy flat subject',
        );

        // Registry rewritten with namespaced paths + runnable name.
        final raw = File(
          p.join(
            tmpDir.path,
            'specs',
            '100-feature-one',
            'tdd',
            'artifacts.json',
          ),
        ).readAsStringSync();
        expect(raw, contains('test/tdd/100-feature-one/a1_test.dart'));
        expect(raw, contains('lib/tdd/100-feature-one/a1_subject.dart'));
        expect(
          raw,
          contains(
            'test/tdd/100-feature-one/a1_test.dart::A1::'
            'returns 42 when invoked with no args',
          ),
        );
        expect(
          raw,
          isNot(contains('test/tdd/a1_test.dart')),
          reason:
              'no flat artifact path may remain anywhere in the migrated '
              'registry (paths and runnable names)',
        );
      },
    );

    test('is idempotent: a second run migrates nothing and exits 0', () async {
      await seedFeature('100-feature-one');
      final testFile = File(p.join(tmpDir.path, 'test', 'tdd', 'a1_test.dart'));
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString('// legacy flat test');
      final subjectFile = File(
        p.join(tmpDir.path, 'lib', 'tdd', 'a1_subject.dart'),
      );
      await subjectFile.parent.create(recursive: true);
      await subjectFile.writeAsString('// legacy flat subject');
      File(
          p.join(
            tmpDir.path,
            'specs',
            '100-feature-one',
            'tdd',
            'artifacts.json',
          ),
        )
        ..parent.create(recursive: true)
        ..writeAsStringSync('''
{
  "feature": "100-feature-one",
  "records": [
    {
      "behavior_id": "A1",
      "feature": "100-feature-one",
      "source_criterion": "FR-007",
      "test_path": "test/tdd/a1_test.dart",
      "subject_path": "lib/tdd/a1_subject.dart",
      "runnable_test_name": "test/tdd/a1_test.dart::A1::returns 42 when invoked with no args",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-01T00:00:00.000Z"
    }
  ]
}
''');

      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(migrateArgs());
      final out2 = await runner.runCapturing(migrateArgs());
      expect(out2, contains('migrated=0'));
      expect(
        File(
          p.join(tmpDir.path, 'test', 'tdd', '100-feature-one', 'a1_test.dart'),
        ).existsSync(),
        isTrue,
      );
    });

    test('refuses to overwrite an existing namespaced target (ownership '
        'guardrail) and leaves both files untouched', () async {
      await seedFeature('100-feature-one');
      // The flat artifact still exists (to be moved)...
      final flatTest = File(p.join(tmpDir.path, 'test', 'tdd', 'a1_test.dart'));
      await flatTest.parent.create(recursive: true);
      await flatTest.writeAsString('// legacy flat test');
      final flatSubject = File(
        p.join(tmpDir.path, 'lib', 'tdd', 'a1_subject.dart'),
      );
      await flatSubject.parent.create(recursive: true);
      await flatSubject.writeAsString('// legacy flat subject');
      // ...but the namespaced target is already taken by other content.
      final taken = File(
        p.join(tmpDir.path, 'test', 'tdd', '100-feature-one', 'a1_test.dart'),
      );
      await taken.parent.create(recursive: true);
      await taken.writeAsString('// already-owned content');
      File(
          p.join(
            tmpDir.path,
            'specs',
            '100-feature-one',
            'tdd',
            'artifacts.json',
          ),
        )
        ..parent.create(recursive: true)
        ..writeAsStringSync('''
{
  "feature": "100-feature-one",
  "records": [
    {
      "behavior_id": "A1",
      "feature": "100-feature-one",
      "source_criterion": "FR-007",
      "test_path": "test/tdd/a1_test.dart",
      "subject_path": "lib/tdd/a1_subject.dart",
      "runnable_test_name": "test/tdd/a1_test.dart::A1::returns 42 when invoked with no args",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-01T00:00:00.000Z"
    }
  ]
}
''');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(migrateArgs());
      expect(
        out,
        contains('REFUSED for behavior "A1"'),
        reason:
            'the refusal must be reported per-record, never silently '
            'skipped (a bare "refused=" summary token would match even a '
            'zero-refusal run)',
      );
      expect(out, contains('refused=1'));
      expect(out, contains('migrated=0'));
      expect(flatTest.readAsStringSync(), '// legacy flat test');
      expect(taken.readAsStringSync(), '// already-owned content');
      // The subject half must NOT have been moved either: the pair moves
      // together or not at all.
      expect(flatSubject.existsSync(), isTrue);
    });

    test(
      'reports a recorded flat artifact whose file is missing and leaves its '
      'record unchanged (fail-honest, no silent rewrite)',
      () async {
        await seedFeature('100-feature-one');
        File(
            p.join(
              tmpDir.path,
              'specs',
              '100-feature-one',
              'tdd',
              'artifacts.json',
            ),
          )
          ..parent.create(recursive: true)
          ..writeAsStringSync('''
{
  "feature": "100-feature-one",
  "records": [
    {
      "behavior_id": "A1",
      "feature": "100-feature-one",
      "source_criterion": "FR-007",
      "test_path": "test/tdd/a1_test.dart",
      "subject_path": "lib/tdd/a1_subject.dart",
      "runnable_test_name": "test/tdd/a1_test.dart::A1::returns 42 when invoked with no args",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-01T00:00:00.000Z"
    }
  ]
}
''');

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(migrateArgs());
        expect(out, contains('missing=1'));
        expect(out, contains('migrated=0'));
        final raw = File(
          p.join(
            tmpDir.path,
            'specs',
            '100-feature-one',
            'tdd',
            'artifacts.json',
          ),
        ).readAsStringSync();
        expect(
          raw,
          contains('"test_path": "test/tdd/a1_test.dart"'),
          reason: 'an unmigratable record stays exactly as it was',
        );
      },
    );

    test('--dry-run reports the planned moves and writes nothing', () async {
      await seedFeature('100-feature-one');
      final testFile = File(p.join(tmpDir.path, 'test', 'tdd', 'a1_test.dart'));
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString('// legacy flat test');
      final subjectFile = File(
        p.join(tmpDir.path, 'lib', 'tdd', 'a1_subject.dart'),
      );
      await subjectFile.parent.create(recursive: true);
      await subjectFile.writeAsString('// legacy flat subject');
      File(
          p.join(
            tmpDir.path,
            'specs',
            '100-feature-one',
            'tdd',
            'artifacts.json',
          ),
        )
        ..parent.create(recursive: true)
        ..writeAsStringSync('''
{
  "feature": "100-feature-one",
  "records": [
    {
      "behavior_id": "A1",
      "feature": "100-feature-one",
      "source_criterion": "FR-007",
      "test_path": "test/tdd/a1_test.dart",
      "subject_path": "lib/tdd/a1_subject.dart",
      "runnable_test_name": "test/tdd/a1_test.dart::A1::returns 42 when invoked with no args",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-01T00:00:00.000Z"
    }
  ]
}
''');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(migrateArgs(['--dry-run']));
      expect(out, contains('dry-run — no changes were written'));
      expect(out, contains('migrated=1'));
      // Nothing moved, nothing rewritten.
      expect(testFile.existsSync(), isTrue);
      expect(subjectFile.existsSync(), isTrue);
      final raw = File(
        p.join(
          tmpDir.path,
          'specs',
          '100-feature-one',
          'tdd',
          'artifacts.json',
        ),
      ).readAsStringSync();
      expect(raw, contains('"test_path": "test/tdd/a1_test.dart"'));
    });

    test(
      'leaves already-namespaced records untouched (mixed-state safety)',
      () async {
        await seedFeature('100-feature-one');
        File(
            p.join(
              tmpDir.path,
              'specs',
              '100-feature-one',
              'tdd',
              'artifacts.json',
            ),
          )
          ..parent.create(recursive: true)
          ..writeAsStringSync('''
{
  "feature": "100-feature-one",
  "records": [
    {
      "behavior_id": "A1",
      "feature": "100-feature-one",
      "source_criterion": "FR-007",
      "test_path": "test/tdd/100-feature-one/a1_test.dart",
      "subject_path": "lib/tdd/100-feature-one/a1_subject.dart",
      "runnable_test_name": "test/tdd/100-feature-one/a1_test.dart::A1::returns 42 when invoked with no args",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-01T00:00:00.000Z"
    }
  ]
}
''');

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(migrateArgs());
        expect(out, contains('migrated=0'));
      },
    );

    test('a REAL generated legacy pair keeps compiling after migration — the '
        "moved test's subject import is rewritten to the namespaced depth and "
        'the cycle log follows', () async {
      await seedFeature('300-legacy-real');
      // The legacy state exactly as a pre-#827 binary left it: the pair
      // written by the REAL writers at the flat layout (so the test
      // carries the flat relative import), a registry record with the
      // flat paths gen recorded, and cycle-log evidence naming them.
      final behavior = Behavior(
        id: 'A1',
        feature: '300-legacy-real',
        kind: BehaviorKind.unit,
        description: 'returns 42 when invoked with no args',
        sourceCriterion: 'FR-007',
        target: 'sampleSubject',
      );
      final flatTestPath = p.join(tmpDir.path, 'test', 'tdd', 'a1_test.dart');
      final flatSubjectPath = p.join(
        tmpDir.path,
        'lib',
        'tdd',
        'a1_subject.dart',
      );
      await const BehaviorTestWriter().write(
        behavior: behavior,
        testPath: flatTestPath,
        subjectPath: flatSubjectPath,
      );
      await const SubjectWriter().write(
        behavior: behavior,
        subjectPath: flatSubjectPath,
      );
      // Fixture sanity: the generated test really carries the flat
      // relative import that dangles once the file moves deeper.
      expect(
        await File(flatTestPath).readAsString(),
        contains("'../../lib/tdd/a1_subject.dart' as subject;"),
      );
      File(
          p.join(
            tmpDir.path,
            'specs',
            '300-legacy-real',
            'tdd',
            'artifacts.json',
          ),
        )
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('''
{
  "feature": "300-legacy-real",
  "records": [
    {
      "behavior_id": "A1",
      "feature": "300-legacy-real",
      "source_criterion": "FR-007",
      "test_path": "$flatTestPath",
      "subject_path": "$flatSubjectPath",
      "runnable_test_name": "$flatTestPath::A1::A1 — returns 42 when invoked with no args",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-01T00:00:00.000Z"
    }
  ]
}
''');
      final cycleLogPath = p.join(
        tmpDir.path,
        'specs',
        '300-legacy-real',
        'tdd',
        'cycle-log.md',
      );
      await File(cycleLogPath).writeAsString('''
# Cycle Log

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- criterion: FR-007
- test: $flatTestPath
- command: `dart test $flatTestPath --plain-name "A1 — returns 42 when invoked with no args"`
- exit: 1
- at: 2026-09-01T00:00:00.000Z
''');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(migrateArgs());
      expect(out, contains('migrated=1'), reason: out);

      // The moved test imports its subject at the namespaced depth —
      // `../../lib/tdd/a1_subject.dart` from inside
      // `test/tdd/<feature>/` resolves to `test/lib/tdd/...` and does
      // not compile, so the rewrite is what keeps the migrated suite
      // green (issue #827 requirement 4).
      final movedTestPath = p.join(
        tmpDir.path,
        'test',
        'tdd',
        '300-legacy-real',
        'a1_test.dart',
      );
      final movedTest = await File(movedTestPath).readAsString();
      expect(
        movedTest,
        contains(
          "'../../../lib/tdd/300-legacy-real/a1_subject.dart' as subject;",
        ),
        reason: movedTest,
      );
      expect(movedTest, isNot(contains('../../lib/tdd/a1_subject.dart')));

      // The rewritten import is exactly what a fresh namespaced gen
      // would render, so the #683 staleness check stays silent on the
      // next gen of this behavior.
      final freshTestPath = p.join(
        tmpDir.path,
        'test',
        'tdd',
        '400-fresh-check',
        'a1_test.dart',
      );
      final freshSubjectPath = p.join(
        tmpDir.path,
        'lib',
        'tdd',
        '400-fresh-check',
        'a1_subject.dart',
      );
      await const BehaviorTestWriter().write(
        behavior: Behavior(
          id: 'A1',
          feature: '400-fresh-check',
          kind: BehaviorKind.unit,
          description: 'returns 42 when invoked with no args',
          sourceCriterion: 'FR-007',
          target: 'sampleSubject',
        ),
        testPath: freshTestPath,
        subjectPath: freshSubjectPath,
      );
      final freshImportLine =
          "import '../../../lib/tdd/400-fresh-check/a1_subject.dart'"
          ' as subject;';
      expect(
        (await File(movedTestPath).readAsString()).contains(
          "import '../../../lib/tdd/300-legacy-real/a1_subject.dart'"
          ' as subject;',
        ),
        isTrue,
      );
      expect(
        await File(freshTestPath).readAsString(),
        contains(freshImportLine),
      );

      // The cycle log's recorded paths follow the move.
      final cycleLog = await File(cycleLogPath).readAsString();
      expect(
        cycleLog,
        contains(p.join('test', 'tdd', '300-legacy-real', 'a1_test.dart')),
      );
      expect(cycleLog, isNot(contains(flatTestPath)));
    });
  });
}
