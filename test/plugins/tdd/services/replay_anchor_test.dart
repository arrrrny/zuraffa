/// Unit behaviors U2 + U5 for spec 0806-zfa-replay: integrity re-anchoring
/// (`ReplayHistory.verifyIntegrity` with a detected `recordedRoot`) and
/// sandbox re-anchoring (`ReplaySandbox.create` rewriting the copied
/// `specs/<feature>/tdd/*.json` registry + seeding `build.yaml` /
/// `dart_test.yaml`).
///
/// The fixture shapes mirror `examples/todo_tdd`'s recorded history: test
/// fields anchored at a recorded root that does not exist locally, and a
/// registry whose `test_path` / `subject_path` / `runnable_test_name` carry
/// the same `<root>/./` prefix.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/services/replay_history.dart';
import 'package:zuraffa/src/plugins/tdd/services/replay_sandbox.dart';

void main() {
  late Directory root;
  late String featureDir;
  const feature = '0806-anchor-fixture';
  const recordedRoot = '/gone/other-box/workspace/todo';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zfa_anchor_');
    featureDir = p.join(root.path, 'specs', feature);
    await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
    await File(
      p.join(root.path, 'pubspec.yaml'),
    ).writeAsString('name: anchor_fx\n');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A minimal machine-format red+green cycle for [id] whose `- test:` fields
  /// carry the recorded-elsewhere `<root>/./` anchor (hand-seeded sections —
  /// `CycleLog.append` writes the same field shapes; the hash chain is not
  /// under test here, so schema-0 entries keep the parser honest).
  Future<void> seedAnchoredCycle(String id) async {
    await File(
      p.join(root.path, 'test', 'tdd', '${id}_test.dart'),
    ).create(recursive: true);
    await File(p.join(featureDir, 'tdd', 'cycle-log.md')).writeAsString('''
# Cycle Log

## Cycle: $id (red)

- behavior: $id
- kind: red
- classification: assertionFailure
- criterion: AC-1
- test: $recordedRoot/./test/tdd/${id}_test.dart
- command: `dart test $recordedRoot/./test/tdd/${id}_test.dart`
- exit: 1
- at: 2026-09-02T09:07:00.603812Z
- output:
```
Expected: not <Instance of 'UnimplementedError'>
```

## Cycle: $id (green)

- behavior: $id
- kind: green
- criterion: AC-1
- test: $recordedRoot/./test/tdd/${id}_test.dart
- command: `dart test $recordedRoot/./test/tdd/${id}_test.dart --name "$id"`
- exit: 0
- at: 2026-09-02T09:08:52.442353Z
- output:
```
All tests passed!
```

''');
  }

  group('U2: verifyIntegrity re-anchors recorded-elsewhere test paths', () {
    test('a red test path anchored at a gone root resolves locally', () async {
      await seedAnchoredCycle('a1');
      final behaviors = await ReplayHistory.load(featureDir);
      expect(behaviors, hasLength(1));

      final outcome = await ReplayHistory.verifyIntegrity(
        behaviors.single,
        projectRoot: root.path,
        recordedRoot: recordedRoot,
      );

      expect(outcome.ok, isTrue, reason: outcome.reason ?? '');
    });

    test(
      'a still-missing artifact diverges naming the recorded path',
      () async {
        // No local test file is written — the re-anchored path resolves to a
        // file that does not exist either.
        await File(p.join(featureDir, 'tdd', 'cycle-log.md')).writeAsString('''
# Cycle Log

## Cycle: a2 (red)

- behavior: a2
- kind: red
- classification: assertionFailure
- criterion: AC-2
- test: $recordedRoot/./test/tdd/a2_test.dart
- command: `dart test $recordedRoot/./test/tdd/a2_test.dart`
- exit: 1
- at: 2026-09-02T09:10:06.683538Z
- output:
```
Expected: not <Instance of 'UnimplementedError'>
```

''');
        final behaviors = await ReplayHistory.load(featureDir);
        final outcome = await ReplayHistory.verifyIntegrity(
          behaviors.single,
          projectRoot: root.path,
          recordedRoot: recordedRoot,
        );

        expect(outcome.ok, isFalse);
        expect(
          outcome.reason,
          'red-missing-test-artifact: $recordedRoot/./test/tdd/a2_test.dart',
        );
      },
    );

    test('a null recorded root keeps 066 same-machine behavior', () async {
      await seedAnchoredCycle('a3');
      final behaviors = await ReplayHistory.load(featureDir);
      // Without a detected root the absolute path resolves as-is and is
      // missing locally → divergence (the pre-0806 behavior).
      final outcome = await ReplayHistory.verifyIntegrity(
        behaviors.single,
        projectRoot: root.path,
      );
      expect(outcome.ok, isFalse);
      expect(outcome.reason, contains('red-missing-test-artifact'));
    });
  });

  group('U5: ReplaySandbox re-anchors the copied registry', () {
    test('ttd/*.json paths rewrite into the sandbox root', () async {
      await seedAnchoredCycle('a1');
      await File(p.join(featureDir, 'tdd', 'artifacts.json')).writeAsString('''
[
  {
    "behavior_id": "a1",
    "feature": "$feature",
    "source_criterion": "AC-1",
    "test_path": "$recordedRoot/./test/tdd/a1_test.dart",
    "subject_path": "$recordedRoot/./lib/tdd/a1_subject.dart",
    "runnable_test_name": "$recordedRoot/./test/tdd/a1_test.dart::a1::desc",
    "test_ownership": "created",
    "subject_ownership": "created",
    "created_at": "2026-09-02T09:06:43.108460Z"
  }
]
''');
      await File(
        p.join(root.path, 'lib', 'tdd', 'a1_subject.dart'),
      ).create(recursive: true);
      await File(
        p.join(root.path, 'test', 'tdd', 'a1_test.dart'),
      ).create(recursive: true);

      final sandbox = await ReplaySandbox.create(
        projectRoot: root.path,
        feature: feature,
        recordedRoot: recordedRoot,
      );
      addTearDown(sandbox.delete);

      final registry = await File(
        p.join(sandbox.path, 'specs', feature, 'tdd', 'artifacts.json'),
      ).readAsString();
      expect(registry, contains('${sandbox.path}/./test/tdd/a1_test.dart'));
      expect(registry, contains('${sandbox.path}/./lib/tdd/a1_subject.dart'));
      expect(registry, isNot(contains(recordedRoot)));
    });

    test(
      'build.yaml and dart_test.yaml seed the sandbox when present',
      () async {
        await seedAnchoredCycle('a1');
        await File(
          p.join(root.path, 'build.yaml'),
        ).writeAsString('targets:\n  all:\n');
        await File(
          p.join(root.path, 'dart_test.yaml'),
        ).writeAsString('tags:\n');

        final sandbox = await ReplaySandbox.create(
          projectRoot: root.path,
          feature: feature,
        );
        addTearDown(sandbox.delete);

        expect(
          File(p.join(sandbox.path, 'build.yaml')).existsSync(),
          isTrue,
          reason: 'recorded zfa build commands read build.yaml from cwd',
        );
        expect(
          File(p.join(sandbox.path, 'dart_test.yaml')).existsSync(),
          isTrue,
          reason: 'recorded dart test commands read dart_test.yaml from cwd',
        );
      },
    );

    test('an anchor-less registry copies verbatim', () async {
      await seedAnchoredCycle('a1');
      final body = '[{"behavior_id": "a1", "test_path": "test/a1_test.dart"}]';
      await File(
        p.join(featureDir, 'tdd', 'artifacts.json'),
      ).writeAsString(body);

      final sandbox = await ReplaySandbox.create(
        projectRoot: root.path,
        feature: feature,
        recordedRoot: recordedRoot,
      );
      addTearDown(sandbox.delete);

      expect(
        await File(
          p.join(sandbox.path, 'specs', feature, 'tdd', 'artifacts.json'),
        ).readAsString(),
        body,
      );
    });
  });
}
