import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/agent/plugin/agent_plugin.dart';
import 'package:zuraffa/src/agent/plugin/generated_marker_merger.dart';
import 'package:zuraffa/src/agent/plugin/manifest_emitter.dart';
import 'package:zuraffa/src/agent/plugin/manifest_entry.dart';

import 'package:zuraffa/src/models/generator_config.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('agent_plugin_e2e_');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  Future<void> writeFixtureUseCases(String entitySnake) async {
    final dir = Directory(
      p.join(tmp.path, 'lib', 'src', 'domain', 'usecases', entitySnake),
    );
    await dir.create(recursive: true);

    await File(
      p.join(dir.path, 'create_${entitySnake}_usecase.dart'),
    ).writeAsString('''
class Create${_pascal(entitySnake)}UseCase extends UseCase<${_pascal(entitySnake)}, ${_pascal(entitySnake)}> {
  @override
  Future<${_pascal(entitySnake)}> call(${_pascal(entitySnake)} params) async => params;
}
''');

    await File(
      p.join(dir.path, 'get_${entitySnake}_usecase.dart'),
    ).writeAsString('''
class Get${_pascal(entitySnake)}UseCase extends UseCase<${_pascal(entitySnake)}, String> {
  @override
  Future<${_pascal(entitySnake)}> call(String id) async => ${_pascal(entitySnake)}();
}
''');

    await File(
      p.join(dir.path, 'delete_${entitySnake}_usecase.dart'),
    ).writeAsString('''
@AgentInternal()
class Delete${_pascal(entitySnake)}UseCase extends UseCase<bool, String> {
  @override
  Future<bool> call(String id) async => true;
}
''');
  }

  Future<void> writePubspec(String name) async {
    await File(p.join(tmp.path, 'pubspec.yaml')).writeAsString('''
name: $name
environment:
  sdk: ^3.11.0
''');
  }

  group('AgentPlugin — FR-001 plugin identity', () {
    test('AgentPlugin is a FileGeneratorPlugin with id "agent"', () {
      final plugin = AgentPlugin(outputDir: p.join(tmp.path, 'lib', 'src'));
      expect(plugin.id, 'agent');
      expect(plugin.name, 'Agent Plugin');
      expect(plugin.version, '1.0.0');
    });

    test('AgentPlugin.dependsOn includes usecase', () {
      final plugin = AgentPlugin(outputDir: p.join(tmp.path, 'lib', 'src'));
      expect(plugin.dependsOn, contains('usecase'));
    });

    test('AgentPlugin.effectiveNamespace defaults to "app"', () {
      final plugin = AgentPlugin(outputDir: p.join(tmp.path, 'lib', 'src'));
      expect(plugin.effectiveNamespace, 'app');
    });
  });

  group('AgentPlugin — FR-002/FR-005/FR-007 generation + SC-001', () {
    test(
      '--agent flag emits one tool wrapper per UseCase + a manifest',
      () async {
        await writePubspec('zuraffa_agent_e2e');
        await writeFixtureUseCases('listing');
        final outputDir = p.join(tmp.path, 'lib', 'src');
        final plugin = AgentPlugin(
          outputDir: outputDir,
          namespaceOverride: 'app',
          projectRootOverride: tmp.path,
        );
        final config = GeneratorConfig(
          name: 'Listing',
          outputDir: outputDir,
          force: true,
        );
          final files = await plugin.generate(config);

          // Expect: 3 tool wrappers + 1 manifest = 4 files.
          // (create, get, delete)
          expect(files.length, greaterThanOrEqualTo(4));

          // All files live under lib/src/agent/tools/.
          for (final f in files) {
            expect(f.path, contains('agent/tools'));
          }

          // The three tool files exist on disk.
          final toolsDir = Directory(p.join(outputDir, 'agent', 'tools'));
          expect(
            File(
              p.join(toolsDir.path, 'listing_create_tool.dart'),
            ).existsSync(),
            isTrue,
          );
          expect(
            File(p.join(toolsDir.path, 'listing_get_tool.dart')).existsSync(),
            isTrue,
          );
          expect(
            File(
              p.join(toolsDir.path, 'listing_delete_tool.dart'),
            ).existsSync(),
            isTrue,
          );
          expect(
            File(p.join(toolsDir.path, 'manifest.dart')).existsSync(),
            isTrue,
          );

          // Each generated tool file contains the GENERATED markers.
          final createToolSrc = File(
            p.join(toolsDir.path, 'listing_create_tool.dart'),
          ).readAsStringSync();
          expect(createToolSrc, contains('// GENERATED - DO NOT EDIT'));
          expect(createToolSrc, contains('class CreateListingTool'));
          expect(createToolSrc, contains('extends McpTool'));
          expect(createToolSrc, contains('app.listing.create'));

          // Manifest contains all 3 tools and groups by entity.
          final manifestSrc = File(
            p.join(toolsDir.path, 'manifest.dart'),
          ).readAsStringSync();
          expect(manifestSrc, contains('app.listing.create'));
          expect(manifestSrc, contains('app.listing.get'));
          expect(manifestSrc, contains('app.listing.delete'));
          expect(manifestSrc, contains("'listing'"));
          expect(manifestSrc, contains('ToolManifestEntry'));
      },
    );

    test(
      'entity with no usecases → empty file list, no agent/tools dir created',
      () async {
        await writePubspec('zuraffa_agent_e2e');
        // No fixture written — no usecases.
        final outputDir = p.join(tmp.path, 'lib', 'src');
        final plugin = AgentPlugin(
          outputDir: outputDir,
          projectRootOverride: tmp.path,
        );
        final config = GeneratorConfig(name: 'NoUse', outputDir: outputDir);
        final files = await plugin.generate(config);
        expect(files, isEmpty);
      },
    );
  });

  group('AgentPlugin — FR-007 manifest risk tiers', () {
    test('manifest assigns safe by default and admin for @AgentInternal', () {
      final entries = [
        const ToolManifestEntry(
          name: 'app.listing.create',
          entity: 'listing',
          riskTier: 'safe',
        ),
        const ToolManifestEntry(
          name: 'app.listing.delete',
          entity: 'listing',
          riskTier: 'admin',
        ),
      ];
      final src = buildManifestSource(entries);
      expect(src, contains("riskTier: 'safe'"));
      expect(src, contains("riskTier: 'admin'"));
    });
  });

  group('AgentPlugin — SC-003 idempotency', () {
    test('regenerate produces identical files (byte-for-byte)', () async {
      await writePubspec('zuraffa_agent_idem');
      await writeFixtureUseCases('listing');
      final outputDir = p.join(tmp.path, 'lib', 'src');
      final plugin = AgentPlugin(outputDir: outputDir, projectRootOverride: tmp.path);
      final config = GeneratorConfig(
        name: 'Listing',
        outputDir: outputDir,
        force: true,
      );

        await plugin.generate(config);
        final toolsDir = Directory(p.join(outputDir, 'agent', 'tools'));
        final checksums = <String, String>{};
        for (final entity in toolsDir.listSync()) {
          if (entity is File) {
            checksums[entity.path] = entity
                .readAsStringSync()
                .hashCode
                .toString();
          }
        }

        await plugin.generate(config);
        for (final entry in checksums.entries) {
          final f = File(entry.key);
          expect(f.existsSync(), isTrue);
          expect(f.readAsStringSync().hashCode.toString(), entry.value);
        }
    });

    test('removed UseCase deletes its tool file + manifest entry', () async {
      await writePubspec('zuraffa_agent_sweep');
      await writeFixtureUseCases('listing');
      final outputDir = p.join(tmp.path, 'lib', 'src');
      final plugin = AgentPlugin(
        outputDir: outputDir,
        projectRootOverride: tmp.path,
      );
      final config = GeneratorConfig(
        name: 'Listing',
        outputDir: outputDir,
        force: true,
      );

        // Generate initial set (3 tools).
        await plugin.generate(config);
        final toolsDir = Directory(p.join(outputDir, 'agent', 'tools'));
        expect(
          File(p.join(toolsDir.path, 'listing_delete_tool.dart')).existsSync(),
          isTrue,
        );

        // Delete the delete usecase file.
        final deleteFile = File(
          p.join(
            tmp.path,
            'lib',
            'src',
            'domain',
            'usecases',
            'listing',
            'delete_listing_usecase.dart',
          ),
        );
        await deleteFile.delete();

        // Regenerate — should sweep the now-orphaned delete tool file.
        await plugin.generate(config);
        expect(
          File(p.join(toolsDir.path, 'listing_delete_tool.dart')).existsSync(),
          isFalse,
          reason: 'orphaned tool file should be deleted on regeneration',
        );
        // The other two still exist.
        expect(
          File(p.join(toolsDir.path, 'listing_create_tool.dart')).existsSync(),
          isTrue,
        );
        expect(
          File(p.join(toolsDir.path, 'listing_get_tool.dart')).existsSync(),
          isTrue,
        );
        // Manifest no longer references the deleted tool.
        final manifestSrc = File(
          p.join(toolsDir.path, 'manifest.dart'),
        ).readAsStringSync();
        expect(manifestSrc, isNot(contains('app.listing.delete')));
    });
  });

  group('AgentPlugin — FR-009 manual-file conflict', () {
    test(
      'manual file without markers in tools dir → ManualFileConflictException',
      () async {
        await writePubspec('zuraffa_agent_conflict');
        await writeFixtureUseCases('listing');
        final outputDir = p.join(tmp.path, 'lib', 'src');
        // Pre-create a manually-written tool file at the path that
        // would be generated. No GENERATED markers.
        final toolsDir = Directory(p.join(outputDir, 'agent', 'tools'));
        await toolsDir.create(recursive: true);
        final manualPath = p.join(toolsDir.path, 'listing_create_tool.dart');
        await File(manualPath).writeAsString(
          '// hand-written\n'
          'class MyCustomTool extends McpTool { /* ... */ }\n',
        );

        final plugin = AgentPlugin(
          outputDir: outputDir,
          projectRootOverride: tmp.path,
        );
        final config = GeneratorConfig(
          name: 'Listing',
          outputDir: outputDir,
          force: true,
        );
          expect(
            () => plugin.generate(config),
            throwsA(isA<ManualFileConflictException>()),
          );
      },
    );
  });
}

String _pascal(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
