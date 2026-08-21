import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/plugins/mcp/mcp_plugin.dart';
import 'package:zuraffa/src/plugins/mcp/capabilities/scaffold_mcp_server_capability.dart';

void main() {
  group('ScaffoldMcpServerCapability', () {
    late Directory tmpDir;
    late McpPlugin plugin;
    late FileSystem fs;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('zuraffa_mcp_plugin_');
      fs = DefaultFileSystem(root: tmpDir.path);
      plugin = McpPlugin(outputDir: 'lib/src', fileSystem: fs);
    });

    tearDown(() async {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    });

    test('name is "scaffold"', () {
      final c = plugin.capabilities
          .whereType<ScaffoldMcpServerCapability>()
          .single;
      expect(c.name, 'scaffold');
    });

    test('inputSchema has dryRun/force/verbose/revert + name props', () {
      final c = plugin.capabilities.first;
      final schema = c.inputSchema;
      expect(schema['type'], 'object');
      final props = schema['properties'] as Map<String, dynamic>;
      expect(
        props.keys,
        containsAll(['name', 'dryRun', 'force', 'verbose', 'revert']),
      );
      expect(schema['required'], isEmpty);
    });

    test('outputSchema declares generatedFiles array', () {
      final c = plugin.capabilities.first;
      final props = c.outputSchema['properties'] as Map<String, dynamic>;
      expect((props['generatedFiles'] as Map)['type'], 'array');
    });

    test('plan() returns an EffectReport listing the planned files', () async {
      final c = plugin.capabilities.first;
      final report = await c.plan({'dryRun': true, 'name': 'my_app'});
      expect(report.isValid, isTrue);
      expect(report.pluginId, 'mcp');
      expect(report.capabilityName, 'scaffold');
      expect(report.changes.length, 2);
      final paths = report.changes.map((e) => e.file).toList();
      expect(paths.any((p) => p.endsWith('mcp/tools.dart')), isTrue);
      expect(paths.any((p) => p.endsWith('bin/mcp_server.dart')), isTrue);
    });

    test('execute() writes the two scaffolded files', () async {
      final c = plugin.capabilities.first;
      final result = await c.execute({'name': 'my_app'});
      expect(result.success, isTrue);
      expect(result.files.length, 2);

      final files = result.data?['generatedFiles'] as List;
      expect(files.length, 2);

      // Verify the files exist on disk under tmpDir.
      final toolsPath = '${tmpDir.path}/lib/src/mcp/tools.dart';
      final binPath = '${tmpDir.path}/bin/mcp_server.dart';
      expect(await File(toolsPath).exists(), isTrue);
      expect(await File(binPath).exists(), isTrue);
    });

    test(
      'execute() without a name resolves the app name from pubspec.yaml',
      () async {
        // No explicit name — _resolveAppName must read pubspec.yaml
        // through the injected plugin.fileSystem.
        await fs.write('pubspec.yaml', 'name: zikzak_demo\nversion: 1.0.0\n');
        final c = plugin.capabilities.first;
        final result = await c.execute({});
        expect(result.success, isTrue);
        final binContent = await fs.read('bin/mcp_server.dart');
        expect(
          binContent,
          contains("import 'package:zikzak_demo/src/mcp/tools.dart';"),
        );
      },
    );

    test(
      'execute() without a name falls back to my_app when no pubspec.yaml exists',
      () async {
        final c = plugin.capabilities.first;
        final result = await c.execute({});
        expect(result.success, isTrue);
        final binContent = await fs.read('bin/mcp_server.dart');
        expect(
          binContent,
          contains("import 'package:my_app/src/mcp/tools.dart';"),
        );
      },
    );

    test('execute() with dryRun=true does not write files', () async {
      final c = plugin.capabilities.first;
      await c.execute({'name': 'my_app', 'dryRun': true});
      expect(
        await File('${tmpDir.path}/lib/src/mcp/tools.dart').exists(),
        isFalse,
      );
      expect(
        await File('${tmpDir.path}/bin/mcp_server.dart').exists(),
        isFalse,
      );
    });

    test('execute() with revert=true deletes existing files', () async {
      final c = plugin.capabilities.first;
      await c.execute({'name': 'my_app'});
      // Files now exist.
      expect(
        await File('${tmpDir.path}/lib/src/mcp/tools.dart').exists(),
        isTrue,
      );
      // Revert.
      final result = await c.execute({'name': 'my_app', 'revert': true});
      expect(result.success, isTrue);
      expect(
        await File('${tmpDir.path}/lib/src/mcp/tools.dart').exists(),
        isFalse,
      );
      expect(
        await File('${tmpDir.path}/bin/mcp_server.dart').exists(),
        isFalse,
      );
    });

    test('execute() without --force skips existing files', () async {
      final c = plugin.capabilities.first;
      await c.execute({'name': 'my_app'});
      final firstContent = await File(
        '${tmpDir.path}/lib/src/mcp/tools.dart',
      ).readAsString();

      // Run again without --force — should skip existing files.
      final result = await c.execute({'name': 'my_app'});
      expect(result.success, isTrue);
      // Every generated file should report action == 'skipped'.
      final files = result.data?['generatedFiles'] as List<GeneratedFile>;
      for (final f in files) {
        expect(f.action, 'skipped');
      }
      // Disk content unchanged.
      final secondContent = await File(
        '${tmpDir.path}/lib/src/mcp/tools.dart',
      ).readAsString();
      expect(secondContent, firstContent);
    });

    test('execute() with --force overwrites existing files', () async {
      final c = plugin.capabilities.first;
      await c.execute({'name': 'my_app'});
      // Tamper with the file.
      final toolsFile = File('${tmpDir.path}/lib/src/mcp/tools.dart');
      await toolsFile.writeAsString('// user customization');
      // Re-run with --force — should overwrite.
      await c.execute({'name': 'my_app', 'force': true});
      final content = await toolsFile.readAsString();
      expect(content, contains('// Generated by zfa'));
      expect(content, isNot(contains('// user customization')));
    });

    test(
      'execute() resolves hyphenated package names from pubspec.yaml',
      () async {
        await File(
          '${tmpDir.path}/pubspec.yaml',
        ).writeAsString('name: my-app\n');
        final c = plugin.capabilities.first;
        final result = await c.execute({});
        expect(result.success, isTrue);

        final binContent = await File(
          '${tmpDir.path}/bin/mcp_server.dart',
        ).readAsString();
        expect(binContent, contains('package:my_app/'));
      },
    );

    test('generated bin/mcp_server.dart imports dart:io', () async {
      final c = plugin.capabilities.first;
      await c.execute({'name': 'my_app'});
      final binContent = await File(
        '${tmpDir.path}/bin/mcp_server.dart',
      ).readAsString();
      expect(binContent, contains("import 'dart:io';"));
    });
  });
}
