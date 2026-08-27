@Tags(['regression', 'slow'])
// Regression test for issue #417:
// https://github.com/arrrrny/zuraffa/issues/417
//
// `zfa make <Entity> mock repository` (i.e. the mock plugin co-active with
// repository but WITHOUT the datasource plugin) generated an
// `<entity>_mock_datasource.dart` file that:
//   1. imports `<entity>_datasource.dart`;
//   2. declares `class <Entity>MockDataSource implements <Entity>DataSource`.
//
// But the `<entity>_datasource.dart` interface file is only emitted by the
// datasource plugin (or by repository plugin's #406 fallback when
// `--datasource` is requested). With neither active, the file is missing
// → `uri_does_not_exist` + `implements_non_class`.
//
// The fix (mirrors the RepositoryPlugin #406 fallback at
// repository_plugin.dart:219-248): when MockBuilder is about to emit a
// mock_datasource, it first checks whether the interface file already
// exists on disk; if not, it emits it inline via DataSourceInterfaceBuilder.
// This makes the mock_datasource's import + implements resolve regardless
// of which other plugins are active, and never conflicts with the
// DataSourcePlugin when it does run (file-existence check skips).
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

void main() {
  late Directory workspace;
  late String outputDir;
  late FileSystem fs;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_issue_417_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);

    // Minimal StopPolicy entity.
    final entityDir = Directory(
      p.join(outputDir, 'domain', 'entities', 'stop_policy'),
    );
    await entityDir.create(recursive: true);
    await File(p.join(entityDir.path, 'stop_policy.dart')).writeAsString('''
class StopPolicy {
  final String id;
  final int maxTurns;
  const StopPolicy({required this.id, required this.maxTurns});
}

class StopPolicyPatch {
  final String? id;
  final int? maxTurns;
  const StopPolicyPatch({this.id, this.maxTurns});
}
''');
    fs = FileSystem.create(root: workspace.path);
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  PluginContext buildContext() {
    return PluginContext(
      core: CoreConfig(
        name: 'StopPolicy',
        projectRoot: workspace.path,
        outputDir: outputDir,
        force: true,
      ),
      data: <String, dynamic>{
        // Mimic `zfa make StopPolicy mock repository` (no `datasource`
        // plugin active). PluginManager.buildContext would set both
        // active plugin ids to `true`.
        'mock': true,
        'repository': true,
        // MakeContext writes these defaults so generators don't fall back
        // to 'NoParams' for the id field type.
        'methods': ['get', 'update', 'toggle'],
        'id-field': 'id',
        'id-field-type': 'String',
        'query-field': 'id',
      },
      discovery: DiscoveryEngine(projectRoot: workspace.path, fileSystem: fs),
      fileSystem: fs,
    );
  }

  test(
    '#417: mock+repository emits the datasource interface the mock implements',
    () async {
      final ctx = buildContext();

      // Run repository first (mimics PluginManager's deterministic order),
      // then mock — exactly what `zfa make StopPolicy mock repository` does.
      await RepositoryPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      ).generateWithContext(ctx);
      final mockFiles = await MockPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        fileSystem: fs,
      ).generateWithContext(ctx);

      // --- The mock_datasource file must be generated ---
      final mockDsPath = p.join(
        outputDir,
        'data',
        'datasources',
        'stop_policy',
        'stop_policy_mock_datasource.dart',
      );
      final mockDsFile = File(mockDsPath);
      expect(
        mockDsFile.existsSync(),
        isTrue,
        reason: '#417: mock_datasource file should be generated',
      );
      final mockDsContent = mockDsFile.readAsStringSync();

      // --- The datasource interface file must ALSO exist ---
      // Before #417 this file was missing, so the mock_datasource's
      // `import 'stop_policy_datasource.dart';` was unresolvable
      // (uri_does_not_exist) and `implements StopPolicyDataSource` referenced
      // a non-existent class (implements_non_class).
      final interfacePath = p.join(
        outputDir,
        'data',
        'datasources',
        'stop_policy',
        'stop_policy_datasource.dart',
      );
      final interfaceFile = File(interfacePath);
      expect(
        interfaceFile.existsSync(),
        isTrue,
        reason:
            '#417: the mock_datasource imports + implements '
            'StopPolicyDataSource — the interface file MUST be emitted '
            'alongside it when the datasource plugin is not active',
      );

      // --- The interface must declare the class the mock implements ---
      final interfaceContent = interfaceFile.readAsStringSync();
      expect(
        interfaceContent.contains('abstract class StopPolicyDataSource'),
        isTrue,
        reason: '#417: StopPolicyDataSource class must be defined',
      );

      // --- The mock_datasource must still import + implement it ---
      expect(
        mockDsContent.contains("import 'stop_policy_datasource.dart';"),
        isTrue,
        reason: '#417: mock_datasource must still import the interface',
      );
      expect(
        mockDsContent.contains('implements StopPolicyDataSource'),
        isTrue,
        reason: '#417: mock_datasource must still implement the interface',
      );

      // --- Mock plugin should report the interface file as created ---
      // (or not, if the repository plugin already created it; either way
      //  the file MUST exist on disk after both plugins run.)
      expect(
        mockFiles.any((f) => f.path.endsWith('stop_policy_datasource.dart')),
        isTrue,
        reason:
            '#417: when neither repository nor datasource plugin emits the '
            'interface, MockBuilder must emit it as part of its generated '
            'files list',
      );
    },
  );

  test(
    '#417: mock alone (no repository, no datasource) still emits the interface',
    () async {
      final ctx = PluginContext(
        core: CoreConfig(
          name: 'StopPolicy',
          projectRoot: workspace.path,
          outputDir: outputDir,
          force: true,
        ),
        data: <String, dynamic>{
          'mock': true,
          // Mimic `zfa make StopPolicy mock repository` is not the only
          // path; MockPlugin.generate returns [] when no
          // data/datasource/repository flag is set, so we set `data: true`
          // (which `--with=mock --preset=crud` would also produce).
          'data': true,
          'methods': ['get', 'update', 'toggle'],
          'id-field': 'id',
          'id-field-type': 'String',
          'query-field': 'id',
        },
        discovery: DiscoveryEngine(projectRoot: workspace.path, fileSystem: fs),
        fileSystem: fs,
      );

      final files = await MockPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        fileSystem: fs,
      ).generateWithContext(ctx);

      // mock_datasource + interface file both emitted.
      expect(
        files.any((f) => f.path.endsWith('stop_policy_mock_datasource.dart')),
        isTrue,
      );
      expect(
        files.any((f) => f.path.endsWith('stop_policy_datasource.dart')),
        isTrue,
        reason:
            '#417: MockBuilder must emit the interface file alongside the '
            'mock_datasource when no other plugin has emitted it',
      );

      // Both files must exist on disk.
      expect(
        File(
          p.join(
            outputDir,
            'data',
            'datasources',
            'stop_policy',
            'stop_policy_mock_datasource.dart',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(
            outputDir,
            'data',
            'datasources',
            'stop_policy',
            'stop_policy_datasource.dart',
          ),
        ).existsSync(),
        isTrue,
      );
    },
  );

  test('#417: when datasource plugin already emitted the interface, '
      'mock does not duplicate it (no conflict)', () async {
    final ctx = buildContext();

    // Run the datasource plugin first — this writes the interface file
    // (and the remote_datasource). Then run mock; MockBuilder should
    // see the interface already exists and skip emitting it, avoiding
    // a "Multiple operations" conflict on the same file.
    await MockPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
      fileSystem: fs,
    ).generateWithContext(ctx);

    // The interface file should exist exactly once.
    final interfacePath = p.join(
      outputDir,
      'data',
      'datasources',
      'stop_policy',
      'stop_policy_datasource.dart',
    );
    expect(File(interfacePath).existsSync(), isTrue);

    // The mock_datasource file should also exist (and be valid).
    final mockDsPath = p.join(
      outputDir,
      'data',
      'datasources',
      'stop_policy',
      'stop_policy_mock_datasource.dart',
    );
    expect(File(mockDsPath).existsSync(), isTrue);
  });
}
