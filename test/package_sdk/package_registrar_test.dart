import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;
  late FileSystem fs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_pkg_di_');
    outputDir = '${tempDir.path}/lib/src';
    await Directory(outputDir).create(recursive: true);
    fs = FileSystem.create(root: tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  PluginContext contextFor() => PluginContext(
    core: CoreConfig(
      name: 'Product',
      projectRoot: tempDir.path,
      outputDir: outputDir,
    ),
    discovery: DiscoveryEngine(projectRoot: tempDir.path),
    fileSystem: fs,
  );

  Future<void> make(String entity) async {
    final plugin = DiPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: false,
        verbose: false,
      ),
    );
    await plugin.generate(
      GeneratorConfig(
        name: entity,
        methods: const ['get'],
        generateData: true,
        generateUseCase: true,
        generateDi: true,
        outputDir: outputDir,
      ),
      context: contextFor(),
    );
  }

  group('DiPlugin package mode (FR-004/FR-012 — spec 025)', () {
    test(
      'U13: package mode emits registrar, NOT service_locator or main index',
      () async {
        File('${tempDir.path}/zfa.yaml').writeAsStringSync('''
package_mode: true
''');
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: my_pkg
''');

        await make('Product');

        final registrar = File('$outputDir/di/my_pkg_package_registrar.dart');
        expect(
          registrar.existsSync(),
          isTrue,
          reason: 'package registrar must be emitted in package mode',
        );
        final content = registrar.readAsStringSync();

        expect(content, contains('registerMyPkgPackage'));
        expect(content, contains('ZuraffaDIContainer'));
        expect(content, contains('registerAllUseCases'));
        expect(content, contains('registerAllDataSources'));
        expect(content, contains('registerAllRepositories'));

        // FR-003/FR-004: no app artifacts in package mode.
        expect(
          File('$outputDir/di/service_locator.dart').existsSync(),
          isFalse,
          reason: 'app service locator must NOT be emitted in package mode',
        );
        expect(
          File('$outputDir/di/index.dart').existsSync(),
          isFalse,
          reason: 'app main index (setupDependencies) must NOT be emitted',
        );
      },
    );

    test(
      'U13b: app mode (no marker) still emits setupDependencies + locator',
      () async {
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: my_app
''');

        await make('Product');

        expect(File('$outputDir/di/index.dart').existsSync(), isTrue);
        expect(
          File('$outputDir/di/index.dart').readAsStringSync(),
          contains('setupDependencies'),
        );
        expect(File('$outputDir/di/service_locator.dart').existsSync(), isTrue);
        expect(
          File('$outputDir/di/my_app_package_registrar.dart').existsSync(),
          isFalse,
        );
      },
    );

    test(
      'U14: registrar aggregates multiple entities in single pass, idempotent',
      () async {
        File('${tempDir.path}/zfa.yaml').writeAsStringSync('''
package_mode: true
''');
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: my_pkg
''');

        await make('Product');
        await make('Order');

        final registrar = File('$outputDir/di/my_pkg_package_registrar.dart');
        expect(registrar.existsSync(), isTrue);
        final content = registrar.readAsStringSync();

        // Both entities' registrations are aggregated through the category
        // index files (registerAll*), one registrar covering every entity.
        expect(content, contains('registerAllUseCases'));
        expect(content, contains('registerAllDataSources'));
        expect(content, contains('registerAllRepositories'));

        // Per-entity register files exist for both entities.
        expect(
          File(
            '$outputDir/di/datasources/product_remote_datasource_di.dart',
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            '$outputDir/di/datasources/order_remote_datasource_di.dart',
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            '$outputDir/di/repositories/order_repository_di.dart',
          ).existsSync(),
          isTrue,
        );

        // Re-running make is idempotent: exactly one registrar function.
        await make('Product');
        final reContent = registrar.readAsStringSync();
        expect(
          'registerMyPkgPackage'.allMatches(reContent).length,
          1,
          reason: 'registrar function must not duplicate on re-runs',
        );
      },
    );

    test(
      'U15: pre-existing scaffold stub registrar is replaced, not duplicated',
      () async {
        File('${tempDir.path}/zfa.yaml').writeAsStringSync('''
package_mode: true
''');
        File('${tempDir.path}/pubspec.yaml').writeAsStringSync('''
name: my_pkg
''');

        // The scaffold writes a stub registrar before any entity exists.
        final stubPath = '$outputDir/di/my_pkg_package_registrar.dart';
        await Directory('$outputDir/di').create(recursive: true);
        File(stubPath).writeAsStringSync('''
// Generated by zfa — package registrar for my_pkg (spec 025, FR-004).
import 'package:zuraffa/zuraffa.dart';

void registerMyPkgPackage(ZuraffaDIContainer di) {
  // Registrations are appended by `zfa make <Entity> ... --di` in
  // package mode (one registrar per package, single pass).
}
''');

        await make('Product');

        final content = File(stubPath).readAsStringSync();
        expect(
          'registerMyPkgPackage'.allMatches(content).length,
          1,
          reason: 'stub function must be replaced, not duplicated',
        );
        expect(content, contains('registerAllUseCases'));
      },
    );
  });
}
