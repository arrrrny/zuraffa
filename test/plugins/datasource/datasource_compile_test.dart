// Spec 077 / issue #1109 — datasource trust tier, compile bar (T015,
// behaviors A11/A12, U11).
//
// `test/plugins/datasource/` carries interface/remote/local structural
// coverage. This suite adds the compile-level behavioral bar (FR-011):
// the generated datasource interface + remote implementation must
// analyze clean inside a self-contained pure-Dart fixture package whose
// entity stub sits at the canonical v5 path.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

import '../../helpers/project_root.dart';

void main() {
  late Directory projectRoot;
  late String libSrc;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    projectRoot = await Directory.systemTemp.createTemp('zfa_ds_compile_');
    libSrc = p.join(projectRoot.path, 'lib', 'src');

    await File(p.join(projectRoot.path, 'pubspec.yaml')).writeAsString('''
name: datasource_compile_fixture
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: $repoRoot
''');

    await _write(
      p.join(libSrc, 'domain', 'entities', 'product', 'product.dart'),
      'class Product {\n'
      '  final String id;\n'
      '  const Product({required this.id});\n'
      '}\n',
    );

    await DataSourcePlugin(
      outputDir: libSrc,
      options: const GeneratorOptions(dryRun: false, force: true),
    ).generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'create'],
        generateData: true,
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
          'dart pub get must succeed in the datasource compile fixture.\n'
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

  test('structural: interface + remote implementation land with the entity '
      'import and per-method members', () {
    final interface = File(
      p.join(
        libSrc,
        'data',
        'datasources',
        'product',
        'product_datasource.dart',
      ),
    );
    final remote = File(
      p.join(
        libSrc,
        'data',
        'datasources',
        'product',
        'product_remote_datasource.dart',
      ),
    );
    expect(interface.existsSync(), isTrue, reason: 'interface missing');
    expect(remote.existsSync(), isTrue, reason: 'remote impl missing');

    final interfaceSrc = interface.readAsStringSync();
    expect(interfaceSrc, contains('abstract class ProductDataSource'));
    expect(
      interfaceSrc,
      contains('Future<Product> get(QueryParams<Product> params);'),
      reason: 'interface must declare the get member',
    );
    expect(
      interfaceSrc,
      contains('Future<Product> create(Product product);'),
      reason: 'interface must declare the create member',
    );
    expect(
      interfaceSrc,
      contains('entities/product/product.dart'),
      reason: 'interface must import the entity at the canonical path',
    );

    final remoteSrc = remote.readAsStringSync();
    expect(remoteSrc, contains('class ProductRemoteDataSource'));
    expect(
      remoteSrc,
      contains("implements ProductDataSource"),
      reason: 'remote impl must implement the interface',
    );
  });

  test('compile: generated datasources pass dart analyze (exit 0)', () async {
    final result = await Process.run('dart', [
      'analyze',
      '--no-fatal-warnings',
      'lib',
    ], workingDirectory: projectRoot.path);
    final output = '${result.stdout}${result.stderr}';
    expect(
      result.exitCode,
      0,
      reason: 'generated datasources must analyze clean. Output:\n$output',
    );
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> _write(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
