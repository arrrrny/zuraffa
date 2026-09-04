import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/state/state_plugin.dart';

import '../../helpers/project_root.dart';

/// Spec 1003 (T002) — compile gate for the `state` trust-tier generator.
///
/// Generates the state class into a self-contained pure-Dart temp project
/// (pubspec with a path dependency on this repo), resolves packages with
/// `dart pub get`, and asserts `dart analyze` exits 0.
///
/// The temp project is pure-Dart (no `flutter:` key), so the generated
/// state imports `package:zuraffa/zuraffa.dart` (#512) — analyzable with
/// the plain Dart SDK, no Flutter needed.
void main() {
  late Directory projectRoot;
  late String repoRoot;

  setUpAll(() async {
    repoRoot = await findProjectRoot();
    projectRoot = await Directory.systemTemp.createTemp(
      'zuraffa_state_compile_',
    );
    await File('${projectRoot.path}/pubspec.yaml').create(recursive: true);
    await File('${projectRoot.path}/pubspec.yaml').writeAsString('''
name: state_compile_fixture
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: $repoRoot
''');
    // Entity stub — the generated state imports the entity file.
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

  test('generated state passes dart analyze (exit 0)', () async {
    final files =
        await StatePlugin(
          outputDir: projectRoot.path,
          options: const GeneratorOptions(dryRun: false, force: true),
        ).generate(
          GeneratorConfig(
            name: 'Product',
            methods: ['get', 'getList', 'create'],
            generateState: true,
            outputDir: projectRoot.path,
          ),
        );
    expect(files, hasLength(1));
    expect(
      File(files.single.path).existsSync(),
      isTrue,
      reason: 'state file must be written to disk, not just returned',
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
      reason: 'generated state must analyze clean. Output:\n$output',
    );
    expect(
      output,
      isNot(contains(' error - ')),
      reason:
          'no analyzer errors allowed in generated state output:\n'
          '$output',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
