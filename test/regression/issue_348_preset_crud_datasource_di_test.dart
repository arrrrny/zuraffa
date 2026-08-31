@Tags(['regression', 'slow'])
// Regression test for issue #348:
// https://github.com/arrrrny/zuraffa/issues/348
//
// `zfa make: preset crud/read-only lack di + datasource activation doesn't
// flow into DI` — the canonical documented flow
//
//     zfa entity create -n ScratchItem --auto-id --field name:String
//     zfa make ScratchItem --preset=crud --with=di --force
//
// produced an app that compiled but crashed at runtime with
// `GetIt: DataSource is not registered`, because:
//   - the `crud` and `read-only` presets did not include the `di` plugin, so
//     `--with=di` was a silent requirement on data presets; and
//   - even with `--with=di`, the repository plugin's `datasource` schema
//     property defaulted to `false` and overrode the plugin-activation
//     sync, so the DI plugin never emitted the datasource registration.
//
// #347 shipped the activation-flag-first sync in PluginManager.buildContext
// (lib/src/core/plugin_system/plugin_manager.dart:94-108) and gated the
// schema-default merge with `!data.containsKey(key)` (line 157-161), which
// fixes the `--with=di` path. #348 closes the remaining half: the `crud`
// and `read-only` presets now bundle `di` (lib/src/core/planning/preset_registry.dart),
// so the canonical one-flag invocation is runnable without `--with=di`.
//
// This regression guard exercises the full CliRunner end-to-end against a
// temp workspace and asserts:
//   1. `--preset=crud --with=di` still produces the datasource DI file
//      (guards the #346/#347 fix path).
//   2. `--preset=crud` ALONE now produces the datasource DI file AND the
//      repository DI file (the #348 preset-consistency fix).
//   3. The repository DI references the datasource via `getIt<…RemoteDataSource>()`
//      so the runtime resolution pattern is intact.
//   4. The DI index `setupDependencies(getIt)` wires up
//      `registerAllDataSources(getIt)` before `registerAllRepositories(getIt)`,
//      so the datasource is registered before the repository tries to resolve it.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  group('issue #348 — preset crud includes di + datasource activation', () {
    late Directory workspace;
    late String outputDir;

    Future<void> writeWorkspacePubspec() {
      return File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_issue_348_test
environment:
  sdk: ^3.11.0
''');
    }

    Future<void> writeProductEntity() async {
      final entityDir = Directory(
        p.join(outputDir, 'domain', 'entities', 'product'),
      );
      await entityDir.create(recursive: true);
      await File(p.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;
  final String name;

  const Product({required this.id, required this.name});
}
''');
    }

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_issue_348_');
      outputDir = p.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      await writeWorkspacePubspec();
      await writeProductEntity();
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test(
      '--preset=crud --with=di generates datasource DI (regression for #346/#347)',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        await runner.run(['-C', workspace.path,
          'make',
          'Product',
          '--preset=crud',
          '--with=di',
          '--output',
          outputDir,
          '--force',
        ]);

        final datasourceDi = File(
          p.join(
            outputDir,
            'di',
            'datasources',
            'product_remote_datasource_di.dart',
          ),
        );
        final repositoryDi = File(
          p.join(outputDir, 'di', 'repositories', 'product_repository_di.dart'),
        );
        final diIndex = File(p.join(outputDir, 'di', 'index.dart'));

        expect(
          datasourceDi.existsSync(),
          isTrue,
          reason: 'datasource DI file must exist for --preset=crud --with=di',
        );
        expect(
          repositoryDi.existsSync(),
          isTrue,
          reason: 'repository DI file must exist for --preset=crud --with=di',
        );
        expect(
          diIndex.existsSync(),
          isTrue,
          reason: 'di/index.dart must exist for --preset=crud --with=di',
        );

        final datasourceContent = datasourceDi.readAsStringSync();
        expect(
          datasourceContent,
          contains('registerLazySingleton<ProductRemoteDataSource>'),
          reason: 'datasource DI must register ProductRemoteDataSource',
        );

        final repositoryContent = repositoryDi.readAsStringSync();
        expect(
          repositoryContent,
          contains('getIt<ProductRemoteDataSource>()'),
          reason:
              'repository DI must resolve the datasource via getIt — '
              'this is the exact #346 runtime-crash pattern when missing',
        );
        expect(
          repositoryContent,
          contains('DataProductRepository'),
          reason: 'repository DI must construct DataProductRepository',
        );

        final indexContent = diIndex.readAsStringSync();
        expect(
          indexContent,
          contains('registerAllDataSources(getIt)'),
          reason: 'setupDependencies must wire up registerAllDataSources',
        );
        expect(
          indexContent,
          contains('registerAllRepositories(getIt)'),
          reason: 'setupDependencies must wire up registerAllRepositories',
        );
        // Datasources must be registered BEFORE repositories so the repository
        // can resolve its datasource dependency at registration time.
        final dsPos = indexContent.indexOf('registerAllDataSources(getIt)');
        final repoPos = indexContent.indexOf('registerAllRepositories(getIt)');
        expect(
          dsPos,
          lessThan(repoPos),
          reason:
              'registerAllDataSources must come before '
              'registerAllRepositories in setupDependencies',
        );
      },
    );

    test(
      '--preset=crud ALONE generates datasource DI (the #348 preset-consistency fix)',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        await runner.run(['-C', workspace.path,
          'make',
          'Product',
          '--preset=crud',
          '--output',
          outputDir,
          '--force',
        ]);

        final datasourceDi = File(
          p.join(
            outputDir,
            'di',
            'datasources',
            'product_remote_datasource_di.dart',
          ),
        );
        final repositoryDi = File(
          p.join(outputDir, 'di', 'repositories', 'product_repository_di.dart'),
        );
        final diIndex = File(p.join(outputDir, 'di', 'index.dart'));

        expect(
          datasourceDi.existsSync(),
          isTrue,
          reason:
              'the canonical `zfa make X --preset=crud` (no --with=di) '
              'must now produce the datasource DI file — this is the #348 fix',
        );
        expect(
          repositoryDi.existsSync(),
          isTrue,
          reason:
              'the canonical `zfa make X --preset=crud` (no --with=di) '
              'must now produce the repository DI file',
        );
        expect(
          diIndex.existsSync(),
          isTrue,
          reason:
              'the canonical `zfa make X --preset=crud` (no --with=di) '
              'must now produce di/index.dart',
        );

        final repositoryContent = repositoryDi.readAsStringSync();
        expect(
          repositoryContent,
          contains('getIt<ProductRemoteDataSource>()'),
          reason:
              'repository DI must resolve the datasource via getIt — '
              'the canonical one-flag flow must be runnable',
        );
      },
    );

    test(
      '--preset=read-only ALONE generates datasource DI (read-only parity with crud)',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        await runner.run(['-C', workspace.path,
          'make',
          'Product',
          '--preset=read-only',
          '--output',
          outputDir,
          '--force',
        ]);

        final datasourceDi = File(
          p.join(
            outputDir,
            'di',
            'datasources',
            'product_remote_datasource_di.dart',
          ),
        );
        final repositoryDi = File(
          p.join(outputDir, 'di', 'repositories', 'product_repository_di.dart'),
        );

        expect(
          datasourceDi.existsSync(),
          isTrue,
          reason:
              'read-only preset must include di and produce the '
              'datasource DI file (same #348 fix as crud)',
        );
        expect(
          repositoryDi.existsSync(),
          isTrue,
          reason: 'read-only preset must produce the repository DI file',
        );

        final repositoryContent = repositoryDi.readAsStringSync();
        expect(
          repositoryContent,
          contains('getIt<ProductRemoteDataSource>()'),
          reason:
              'read-only repository DI must resolve the datasource via getIt',
        );
      },
    );
  });
}
