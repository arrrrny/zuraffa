// Spec 893 — committed per-entity fixtures (T003).
//
// FR-003: every mock datasource uses committed fixtures from
// `specs/<feature>/tdd/fixtures/`, extending the #832 fixture registry.
// `zfa mock create <entity> --fixtures-dir <dir>` commits the entity's
// fixture JSON and re-certifies it through the same SHA-256 manifest +
// hash-chained cycle evidence the certified simulation worlds use.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/create_mock_capability.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/simulation/fixture_registry.dart';

void main() {
  late Directory tempDir;
  late String outputDir;
  late String featureDir;
  late String fixturesDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_893_fixture_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
    featureDir = '${tempDir.path}/specs/893-fixture-feature';
    fixturesDir = '$featureDir/tdd/fixtures';

    // Seed the domain entity the way real projects provide it.
    final entityDir = Directory('$outputDir/domain/entities/todo');
    await entityDir.create(recursive: true);
    await File('${entityDir.path}/todo.dart').writeAsString(
      'class Todo { final String id; final String title; final bool done; '
      'const Todo(this.id, this.title, this.done); }',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  CreateMockCapability capability(MockPlugin plugin) =>
      CreateMockCapability(plugin);

  test(
    'U14: mock create commits per-entity fixtures through the fixture registry',
    () async {
      final plugin = MockPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      final result = await capability(plugin).execute({
        'name': 'Todo',
        'methods': ['get', 'update'],
        'fixturesDir': fixturesDir,
      });

      expect(result.success, isTrue);

      // The committed fixture file exists and carries the entity records.
      final fixtureFile = File('$fixturesDir/todo_fixtures.json');
      expect(
        fixtureFile.existsSync(),
        isTrue,
        reason:
            'per-entity fixture JSON must be committed under the '
            'feature fixtures directory',
      );

      final fixtureJson =
          jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
      expect(fixtureJson['entity'], 'Todo');
      expect(fixtureJson['schema'], 1);
      expect(fixtureJson['spec'], 893);
      final records = fixtureJson['records'] as List<dynamic>;
      expect(records, isNotEmpty);
      expect(records.first, isA<Map<String, dynamic>>());
      // Deterministic demo content derived from the entity fields.
      expect(
        (records.first as Map<String, dynamic>).containsKey('title'),
        isTrue,
      );

      // The #832 registry certifies the fixtures directory: the manifest
      // covers the new fixture file and verifies against the bytes on
      // disk.
      final manifest = await FixtureRegistry(fixturesDir).readManifest();
      expect(
        (manifest['files'] as Map<String, dynamic>).keys,
        contains('todo_fixtures.json'),
      );
      await FixtureRegistry(fixturesDir).verifyManifest();

      // Hash-chained cycle evidence records the commitment (bug #832
      // requirement 3, reused for spec 893).
      final cycleLog = File('$featureDir/tdd/cycle-log.md');
      expect(cycleLog.existsSync(), isTrue);
      final logContent = cycleLog.readAsStringSync();
      expect(logContent, contains('- kind: fixtures'));
      expect(logContent, contains('- behavior: 893-fixture-feature-fixtures'));
      expect(logContent, contains('todo_fixtures.json='));
    },
  );

  test(
    're-running mock create re-certifies without duplicating fixtures',
    () async {
      final plugin = MockPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      await capability(
        plugin,
      ).execute({'name': 'Todo', 'fixturesDir': fixturesDir});
      await capability(
        plugin,
      ).execute({'name': 'Todo', 'fixturesDir': fixturesDir});

      final fixtureFile = File('$fixturesDir/todo_fixtures.json');
      expect(fixtureFile.existsSync(), isTrue);
      // The digest stays stable for identical fixture bytes.
      final firstDigest = (await FixtureRegistry(
        fixturesDir,
      ).readManifest())['digest'];
      await capability(
        plugin,
      ).execute({'name': 'Todo', 'fixturesDir': fixturesDir});
      final secondDigest = (await FixtureRegistry(
        fixturesDir,
      ).readManifest())['digest'];
      expect(secondDigest, firstDigest);
    },
  );

  test('no fixture file is written without --fixtures-dir', () async {
    final plugin = MockPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    await capability(plugin).execute({'name': 'Todo'});

    expect(Directory(fixturesDir).existsSync(), isFalse);
  });
}
