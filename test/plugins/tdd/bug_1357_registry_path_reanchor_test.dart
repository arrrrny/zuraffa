// Issue #1357 — the fuzz preflight's "the tests never ran" misfire:
// committed registries can carry SANDBOX-ABSOLUTE paths
// (`/home/z/my-project/zuraffa/test/tdd/...`), so every other
// environment fails to load them and `zfa spec fuzz` reports
// notAssessed forever.
//
// Contract under test (spec 1357-registry-path-reanchor):
//   B1 — a registry with stale absolute paths loads with repo-relative
//        `test/...` / `lib/...` paths and a re-anchored
//        `runnable_test_name` prefix.
//   B2 — an absolute path that exists on disk is kept verbatim.
//   B3 — an absolute path with no resolvable suffix passes through.
//   B4 — relative paths pass through untouched.
//   B5 — MutationScope.derive over the healed registry yields existing
//        test paths (the fuzz preflight's root cause is gone).

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/artifact_registry.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_scope.dart';

void main() {
  late Directory root;
  late String featureDir;

  /// Writes `<root>/specs/<feature>/tdd/artifacts.json` with a single
  /// record built from [record], creating the real artifact files whose
  /// [recordPaths] (test/subject) point into it.
  Future<void> seedRegistry(Map<String, String> record) async {
    final tdd = Directory(p.join(root.path, 'specs', '035-fixture', 'tdd'))
      ..createSync(recursive: true);
    File(p.join(tdd.path, 'artifacts.json')).writeAsStringSync(
      jsonEncode({
        'feature': '035-fixture',
        'records': [record],
      }),
    );
  }

  Map<String, String> baseRecord({
    required String testPath,
    required String subjectPath,
    required String runnableTestName,
  }) => {
    'behavior_id': 'A1',
    'feature': '035-fixture',
    'source_criterion': 'AC-1',
    'test_path': testPath,
    'subject_path': subjectPath,
    'runnable_test_name': runnableTestName,
    'test_ownership': 'created',
    'subject_ownership': 'created',
    'created_at': '2026-09-09T06:04:00.000Z',
  };

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zfa-1357');
    featureDir = p.join(root.path, 'specs', '035-fixture');

    // The portable suffixes the sandbox paths must re-anchor to.
    final testFile = File(
      p.join(root.path, 'test', 'tdd', '035-fixture', 'a1_test.dart'),
    )..createSync(recursive: true);
    testFile.writeAsStringSync('void main() {}');
    final subjectFile = File(
      p.join(root.path, 'lib', 'tdd', '035-fixture', 'a1_subject.dart'),
    )..createSync(recursive: true);
    subjectFile.writeAsStringSync('void main() {}');
  });

  tearDown(() => root.delete(recursive: true));

  test('B1: sandbox-absolute paths re-anchor to repo-relative on load', () async {
    await seedRegistry(
      baseRecord(
        testPath:
            '/home/z/my-project/zuraffa/test/tdd/035-fixture/a1_test.dart',
        subjectPath:
            '/home/z/my-project/zuraffa/lib/tdd/035-fixture/a1_subject.dart',
        runnableTestName:
            '/home/z/my-project/zuraffa/test/tdd/035-fixture/a1_test.dart'
            '::A1::the verdict is invalid with a reason naming the email field first.',
      ),
    );

    final records = await ArtifactRegistry(featureDir: featureDir).loadAll();

    expect(records, hasLength(1));
    expect(
      records.single.testPath,
      'test/tdd/035-fixture/a1_test.dart',
      reason: 'the sandbox prefix is stripped to the repo-relative lane',
    );
    expect(records.single.subjectPath, 'lib/tdd/035-fixture/a1_subject.dart');
    expect(
      records.single.runnableTestName,
      startsWith('test/tdd/035-fixture/a1_test.dart::A1::'),
      reason: 'the runnable grammar keeps <path>::<id>::<name>',
    );
    expect(
      File(p.join(root.path, records.single.testPath)).existsSync(),
      isTrue,
      reason: 'the healed path is runnable under the project root',
    );
  });

  test('B2: an absolute path that exists on disk is kept verbatim', () async {
    final existing = p.join(
      root.path,
      'test',
      'tdd',
      '035-fixture',
      'a1_test.dart',
    );
    await seedRegistry(
      baseRecord(
        testPath: existing,
        subjectPath: 'lib/tdd/035-fixture/a1_subject.dart',
        runnableTestName: '$existing::A1::some behavior name',
      ),
    );

    final records = await ArtifactRegistry(featureDir: featureDir).loadAll();

    expect(records.single.testPath, existing);
  });

  test(
    'B3: an absolute path with no resolvable suffix passes through',
    () async {
      const stale = '/opt/other-checkout/test/other-feature/a9_test.dart';
      await seedRegistry(
        baseRecord(
          testPath: stale,
          subjectPath: 'lib/tdd/035-fixture/a1_subject.dart',
          runnableTestName: '$stale::A9::some behavior name',
        ),
      );

      final records = await ArtifactRegistry(featureDir: featureDir).loadAll();

      expect(records.single.testPath, stale);
    },
  );

  test('B4: relative paths pass through untouched', () async {
    await seedRegistry(
      baseRecord(
        testPath: 'test/tdd/035-fixture/a1_test.dart',
        subjectPath: 'lib/tdd/035-fixture/a1_subject.dart',
        runnableTestName:
            'test/tdd/035-fixture/a1_test.dart::A1::some behavior name',
      ),
    );

    final records = await ArtifactRegistry(featureDir: featureDir).loadAll();

    expect(records.single.testPath, 'test/tdd/035-fixture/a1_test.dart');
    expect(records.single.subjectPath, 'lib/tdd/035-fixture/a1_subject.dart');
    expect(
      records.single.runnableTestName,
      'test/tdd/035-fixture/a1_test.dart::A1::some behavior name',
    );
  });

  test('B5: MutationScope.derive over the healed registry yields '
      'existing test paths', () async {
    await seedRegistry(
      baseRecord(
        testPath:
            '/home/z/my-project/zuraffa/test/tdd/035-fixture/a1_test.dart',
        subjectPath:
            '/home/z/my-project/zuraffa/lib/tdd/035-fixture/a1_subject.dart',
        runnableTestName:
            '/home/z/my-project/zuraffa/test/tdd/035-fixture/a1_test.dart'
            '::A1::some behavior name',
      ),
    );

    final scope = await MutationScope.derive(featureDir: featureDir);

    expect(scope.testPaths, hasLength(1));
    expect(
      File(p.join(root.path, scope.testPaths.single)).existsSync(),
      isTrue,
      reason: 'the fuzz preflight spawns dart test over EXISTING paths',
    );
  });
}
