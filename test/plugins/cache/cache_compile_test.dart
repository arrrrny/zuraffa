import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/cache/cache_plugin.dart';

import '../../helpers/project_root.dart';

/// Spec 1003 (T002) — compile gate for the `cache` trust-tier generator.
///
/// Generates the Hive cache file set into a self-contained pure-Dart temp
/// project (pubspec with a path dependency on this repo plus an entity
/// stub), resolves packages with `dart pub get`, and asserts `dart
/// analyze` exits 0.
void main() {
  late Directory projectRoot;
  late String repoRoot;

  setUpAll(() async {
    repoRoot = await findProjectRoot();
    projectRoot = await Directory.systemTemp.createTemp(
      'zuraffa_cache_compile_',
    );
    await File('${projectRoot.path}/pubspec.yaml').create(recursive: true);
    await File('${projectRoot.path}/pubspec.yaml').writeAsString('''
name: cache_compile_fixture
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: $repoRoot
''');
    await File(
      '${projectRoot.path}/domain/entities/product/product.dart',
    ).create(recursive: true);
    await File(
      '${projectRoot.path}/domain/entities/product/product.dart',
    ).writeAsString('''
class Product {
  Product({this.id});

  final String? id;
}
''');
    final pub = await Process.run('dart', [
      'pub',
      'get',
      '--no-example',
    ], workingDirectory: projectRoot.path);
    expect(
      pub.exitCode,
      0,
      reason:
          'dart pub get must succeed in the compile fixture.\n'
          '${pub.stdout}\n${pub.stderr}',
    );
  });

  tearDownAll(() async {
    if (projectRoot.existsSync()) {
      await projectRoot.delete(recursive: true);
    }
  });

  test('generated cache files pass dart analyze (exit 0)', () async {
    final files =
        await CachePlugin(
          outputDir: projectRoot.path,
          options: const GeneratorOptions(dryRun: false, force: true),
        ).generate(
          GeneratorConfig(
            name: 'Product',
            methods: ['get'],
            enableCache: true,
            cacheStorage: 'hive',
            outputDir: projectRoot.path,
          ),
        );
    expect(files, hasLength(3));
    for (final file in files) {
      expect(
        File(file.path).existsSync(),
        isTrue,
        reason: '${file.path} must be written to disk',
      );
    }

    // The registrar side-writes cache/hive_registrar.dart whose
    // `part 'hive_registrar.g.dart'` adapter file is produced by the
    // documented `build_runner build` step (zfa entity create --build).
    // Emit the post-build adapter so the full cache set can be gated
    // without spinning up build_runner.
    await File(
      '${projectRoot.path}/cache/hive_registrar.g.dart',
    ).create(recursive: true);
    await File('${projectRoot.path}/cache/hive_registrar.g.dart').writeAsString(
      '''
// GENERATED - DO NOT EDIT
// Simulates the hive_ce generator output for @GenerateAdapters.
part of 'hive_registrar.dart';

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 1;

  @override
  Product read(BinaryReader reader) => Product();

  @override
  void write(BinaryWriter writer, Product obj) {}
}
''',
    );

    final result = await Process.run('dart', [
      'analyze',
      '--no-fatal-warnings',
      projectRoot.path,
    ], workingDirectory: projectRoot.path);
    final output = '${result.stdout}${result.stderr}';

    expect(
      result.exitCode,
      0,
      reason: 'generated cache files must analyze clean. Output:\n$output',
    );
    expect(
      output,
      isNot(contains(' error - ')),
      reason:
          'no analyzer errors allowed in generated cache output:\n'
          '$output',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
