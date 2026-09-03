@Tags(['regression'])
library;

// Regression tests for issue #942:
// https://github.com/arrrrny/zuraffa/issues/942
//
// An entity whose name matches a zuraffa core export (e.g. `Credentials`,
// exported by `package:zuraffa/zuraffa.dart` via
// `src/core/params/index.dart`) makes every GENERATED datasource/mock
// file non-compiling: those templates import the entity file AND the
// framework barrel (or `package:zuraffa/mock.dart`) UNPREFIXED, so the
// entity's own symbols and the framework's symbols become ambiguous
// (`ambiguous_import`) at every use site. 20 errors on the #942 repro;
// `zfa build` fails and the generated tree never compiles.
//
// Remediation (1) of the #942 assessment: the generator knows the
// entity's own symbols, so the barrel import it emits carries a `hide`
// clause for them (`Credentials`, `CredentialsPatch` — the zorphy
// concrete class + patch pair an entity file exports). The framework
// barrel keeps exporting everything else, the entity keeps its own
// name, and the generated code compiles.
//
// Remediation (2): `entity create` preflights the name against the
// framework's export surface and refuses with a `--> fix:` rename
// suggestion (VISION §4 — errors are an API), so users never walk into
// the trap for NEW entities.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/plugins/sqlite/builders/sqlite_datasource_builder.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;
  late String outputDir;
  late FileSystem fs;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_issue_942_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_issue_942_test
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
''');
    fs = FileSystem.create(root: workspace.path);
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  /// Seeds an entity file for [name] under the workspace the way
  /// `zfa entity create` would (content shape irrelevant to directive
  /// emission — what matters is that the file EXISTS so the builders
  /// take the entity-import branch).
  Future<void> seedEntity(String name) async {
    final snake = name
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => '_${m.group(1)!.toLowerCase()}',
        )
        .replaceFirst(RegExp('^_'), '');
    final dir = Directory(p.join(outputDir, 'domain', 'entities', snake));
    await dir.create(recursive: true);
    await File(p.join(dir.path, '$snake.dart')).writeAsString('''
class $name {
  final String id;
  const $name({required this.id});
}

class ${name}Patch {}
''');
  }

  /// Resolves a generated file's content: prefer the in-memory content
  /// the builders report, fall back to the absolute on-disk path.
  String contentOf(GeneratedFile f) {
    final content = f.content;
    if (content != null) return content;
    final path = p.isAbsolute(f.path) ? f.path : p.join(workspace.path, f.path);
    return File(path).readAsStringSync();
  }

  PluginContext context({required Map<String, dynamic> data}) {
    return PluginContext(
      core: CoreConfig(
        name: 'Credentials',
        projectRoot: workspace.path,
        outputDir: outputDir,
        force: true,
      ),
      data: data,
      discovery: DiscoveryEngine(projectRoot: workspace.path, fileSystem: fs),
      fileSystem: fs,
    );
  }

  group('#942 defect 1 — generated files hide the entity symbols from the '
      'framework barrel', () {
    test(
      'mock datasource hides Credentials from package:zuraffa/mock.dart',
      () async {
        await seedEntity('Credentials');
        final files =
            await MockPlugin(
              outputDir: outputDir,
              options: const GeneratorOptions(force: true),
              fileSystem: fs,
            ).generateWithContext(
              context(
                data: <String, dynamic>{
                  'mock': true,
                  'data': true,
                  'methods': ['get', 'update', 'toggle'],
                  'id-field': 'id',
                  'id-field-type': 'String',
                  'query-field': 'id',
                },
              ),
            );

        final content = contentOf(
          files.firstWhere((f) => f.path.endsWith('mock_datasource.dart')),
        );

        expect(
          content,
          contains("import 'package:zuraffa/mock.dart' hide Credentials"),
          reason:
              '#942: the mock datasource imports BOTH the entity file and '
              'the framework mock barrel — the barrel import must hide the '
              "entity's own symbols so Credentials resolves to the entity, "
              'not to the framework param (out:\n$content)',
        );
        expect(
          content,
          contains('CredentialsPatch'),
          reason:
              '#942: the patch symbol is generated and referenced too '
              '(out:\n$content)',
        );
      },
    );

    test('datasource interface + remote hide Credentials from the framework '
        'barrel', () async {
      await seedEntity('Credentials');
      final files =
          await DataSourcePlugin(
            outputDir: outputDir,
            options: const GeneratorOptions(force: true),
          ).generateWithContext(
            context(
              data: <String, dynamic>{
                'datasource': true,
                'methods': ['get', 'update'],
                'id-field': 'id',
                'id-field-type': 'String',
                'query-field': 'id',
              },
            ),
          );

      final datasourceFiles = files
          .where(
            (f) =>
                f.path.endsWith('credentials_datasource.dart') ||
                f.path.endsWith('credentials_remote_datasource.dart'),
          )
          .toList();
      expect(datasourceFiles, isNotEmpty);

      for (final f in datasourceFiles) {
        final content = contentOf(f);
        expect(
          content,
          contains(
            "import 'package:zuraffa/zuraffa.dart' hide Credentials, "
            'CredentialsPatch;',
          ),
          reason:
              '#942: ${f.path} imports the entity file AND the framework '
              'barrel unprefixed — the barrel import must hide the entity '
              'symbols (out:\n$content)',
        );
      }
    });

    test(
      'sqlite datasource hides Credentials from the framework barrel',
      () async {
        await seedEntity('Credentials');
        final files =
            await SqliteDataSourceBuilder(
              outputDir: outputDir,
              options: const GeneratorOptions(force: true),
            ).generate(
              GeneratorConfig(
                name: 'Credentials',
                outputDir: outputDir,
                methods: ['get', 'update'],
              ),
            );

        final content = contentOf(files.first);
        expect(
          content,
          contains(
            "import 'package:zuraffa/zuraffa.dart' hide Credentials, "
            'CredentialsPatch;',
          ),
          reason:
              '#942: the sqlite datasource imports the entity file '
              'UNCONDITIONALLY plus the framework barrel — the barrel import '
              'must hide the entity symbols (out:\n$content)',
        );
      },
    );

    test('a non-colliding entity is unaffected: barrel import still emitted, '
        'class shape unchanged', () async {
      await seedEntity('Order');
      final files =
          await MockPlugin(
            outputDir: outputDir,
            options: const GeneratorOptions(force: true),
            fileSystem: fs,
          ).generateWithContext(
            PluginContext(
              core: CoreConfig(
                name: 'Order',
                projectRoot: workspace.path,
                outputDir: outputDir,
                force: true,
              ),
              data: <String, dynamic>{
                'mock': true,
                'data': true,
                'methods': ['get', 'update', 'toggle'],
                'id-field': 'id',
                'id-field-type': 'String',
                'query-field': 'id',
              },
              discovery: DiscoveryEngine(
                projectRoot: workspace.path,
                fileSystem: fs,
              ),
              fileSystem: fs,
            ),
          );

      final content = contentOf(
        files.firstWhere((f) => f.path.endsWith('mock_datasource.dart')),
      );

      // The barrel import is still there (now with the entity's own
      // symbols hidden — uniform, deterministic codegen for every
      // entity) and the class still implements its datasource.
      expect(
        content,
        contains("import 'package:zuraffa/mock.dart' hide Order"),
        reason: 'out:\n$content',
      );
      expect(content, contains('class OrderMockDataSource'));
      expect(content, contains('implements OrderDataSource'));
    });
  });

  group('#942 remediation 2 — entity create preflights the framework '
      'export surface', () {
    test('entity create refuses a framework-exported name with a '
        '--> fix: rename suggestion', () async {
      final result = await runZfaSource([
        'entity',
        'create',
        '-n',
        'Credentials',
        '--fields',
        'id:String',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 1, reason: 'stdout=${result.stdout}');
      expect(
        result.stdout,
        contains('--> fix:'),
        reason:
            'VISION §4 errors-are-an-API: the refusal must end with a '
            'machine-actionable fix line (stdout=${result.stdout})',
      );
      expect(result.stdout, contains('rename'));
      // No files were written.
      expect(
        File(
          p.join(
            workspace.path,
            'lib',
            'src',
            'domain',
            'entities',
            'credentials',
            'credentials.dart',
          ),
        ).existsSync(),
        isFalse,
        reason: 'the refusal happens BEFORE any file is written',
      );
    });

    test('a non-colliding name still creates the entity', () async {
      final result = await runZfaSource([
        'entity',
        'create',
        '-n',
        'UserCredentials',
        '--fields',
        'id:String',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 0, reason: 'stdout=${result.stdout}');
      expect(result.stdout, contains('✓ Created entity'));
    });
  });
}
