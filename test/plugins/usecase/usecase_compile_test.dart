// Spec 077 / issue #1109 — usecase trust tier, compile bar (T012,
// behaviors A11/A12, U11).
//
// `test/plugins/usecase/` already carries deep structural coverage
// (entity_usecase_generator_test.dart & friends). This suite adds the
// compile-level behavioral bar FR-011 demands: the generator's output
// must analyze clean inside a self-contained pure-Dart fixture package
// (pubspec with a path dependency on this repo), so a generator
// regression that breaks compilability fails the suite naming the
// artifact — not the user's build.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

import '../../helpers/project_root.dart';

void main() {
  late Directory projectRoot;
  late String libSrc;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    projectRoot = await Directory.systemTemp.createTemp('zfa_uc_compile_');
    libSrc = p.join(projectRoot.path, 'lib', 'src');

    await File(p.join(projectRoot.path, 'pubspec.yaml')).writeAsString('''
name: usecase_compile_fixture
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: $repoRoot
''');

    // Entity + repository interface stubs: the shapes the generated
    // usecases import and call (mirrors the repository compile fixture).
    await _write(
      p.join(libSrc, 'domain', 'entities', 'product', 'product.dart'),
      'class Product {\n'
      '  final String id;\n'
      '  const Product({required this.id});\n'
      '}\n',
    );
    await _write(
      p.join(libSrc, 'domain', 'repositories', 'product_repository.dart'),
      "import 'package:zuraffa/zuraffa.dart';\n"
      "import '../entities/product/product.dart';\n"
      'abstract class ProductRepository {\n'
      '  Future<Product> get(QueryParams<Product> params);\n'
      '  Future<Product> create(Product product);\n'
      '}\n',
    );

    await UseCasePlugin(
      outputDir: libSrc,
      options: const GeneratorOptions(dryRun: false, force: true),
    ).generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'create'],
        outputDir: libSrc,
      ),
    );

    final pub = await Process.run('dart', [
      'pub',
      'get',
      '--no-example',
    ], workingDirectory: projectRoot.path);
    expect(
      pub.exitCode,
      0,
      reason:
          'dart pub get must succeed in the usecase compile fixture.\n'
          '${pub.stdout}\n${pub.stderr}',
    );
  });

  tearDownAll(() async {
    if (projectRoot.existsSync()) {
      try {
        await projectRoot.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  test('structural: per-method usecases land at the canonical paths with '
      'the expected class shapes', () {
    final get = File(
      p.join(
        libSrc,
        'domain',
        'usecases',
        'product',
        'get_product_usecase.dart',
      ),
    );
    final create = File(
      p.join(
        libSrc,
        'domain',
        'usecases',
        'product',
        'create_product_usecase.dart',
      ),
    );
    expect(get.existsSync(), isTrue, reason: 'get usecase missing');
    expect(create.existsSync(), isTrue, reason: 'create usecase missing');

    expect(
      get.readAsStringSync(),
      contains('class GetProductUseCase extends UseCase<Product,'),
      reason: 'get usecase signature must match the UseCase contract',
    );
    expect(
      create.readAsStringSync(),
      contains('_repository.create(params)'),
      reason: 'create usecase must delegate to the repository',
    );
    // Only requested methods are generated.
    expect(
      File(
        p.join(
          libSrc,
          'domain',
          'usecases',
          'product',
          'delete_product_usecase.dart',
        ),
      ).existsSync(),
      isFalse,
      reason: 'unrequested methods must not be generated',
    );
  });

  test('compile: generated usecases pass dart analyze (exit 0)', () async {
    final result = await Process.run('dart', [
      'analyze',
      '--no-fatal-warnings',
      'lib',
    ], workingDirectory: projectRoot.path);
    final output = '${result.stdout}${result.stderr}';
    expect(
      result.exitCode,
      0,
      reason: 'generated usecases must analyze clean. Output:\n$output',
    );
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _write(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
