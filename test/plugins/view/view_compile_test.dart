@Tags(['flutter'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

import '../helpers/flutter_cluster_fixture.dart';

/// Spec 1003 (T001) — compile gate for the `view` trust-tier generator.
///
/// Generates the full presentation cluster (view + controller + presenter)
/// with the real plugins into a temp Flutter project, resolves packages
/// with `flutter pub get`, and asserts `flutter analyze` exits 0.
///
/// Tagged `flutter`: needs the Flutter SDK, so it runs in the CI flutter
/// lane (`flutter test --tags flutter`) and is excluded from the pure-Dart
/// lane (`dart test --exclude-tags flutter`).
void main() {
  late Directory projectRoot;
  late String flutterExe;

  setUpAll(() async {
    projectRoot = await createFlutterClusterFixture('view_compile');
    flutterExe = await resolveFlutterExe();
    final pub = await flutterPubGet(projectRoot, flutterExe);
    expect(
      pub.exitCode,
      0,
      reason:
          'flutter pub get must succeed in the compile fixture.\n'
          '${pub.stdout}\n${pub.stderr}',
    );
  });

  tearDownAll(() async {
    if (projectRoot.existsSync()) {
      await projectRoot.delete(recursive: true);
    }
  });

  test('generated view cluster passes flutter analyze (exit 0)', () async {
    const opts = GeneratorOptions(dryRun: false, force: true);
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get'],
      generateView: true,
      outputDir: projectRoot.path,
    );

    final viewFiles = await ViewPlugin(
      outputDir: projectRoot.path,
      options: opts,
    ).generate(config);
    expect(viewFiles, hasLength(1));

    final presenterFiles =
        await PresenterPlugin(
          outputDir: projectRoot.path,
          options: opts,
        ).generate(
          GeneratorConfig(
            name: 'Product',
            methods: ['get'],
            generatePresenter: true,
            outputDir: projectRoot.path,
          ),
        );
    expect(presenterFiles, hasLength(1));

    final controllerFiles =
        await ControllerPlugin(
          outputDir: projectRoot.path,
          options: opts,
        ).generate(
          GeneratorConfig(
            name: 'Product',
            methods: ['get'],
            generateController: true,
            outputDir: projectRoot.path,
          ),
        );
    expect(controllerFiles, hasLength(1));

    final viewFile = File(
      p.join(
        projectRoot.path,
        'presentation',
        'pages',
        'product',
        'product_view.dart',
      ),
    );
    expect(viewFile.existsSync(), isTrue);

    final result = await Process.run(flutterExe, [
      'analyze',
      '--no-fatal-warnings',
      p.join('presentation', 'pages', 'product'),
    ], workingDirectory: projectRoot.path);
    final output = '${result.stdout}${result.stderr}';

    expect(
      result.exitCode,
      0,
      reason: 'generated view cluster must analyze clean. Output:\n$output',
    );
    expect(
      output,
      isNot(contains(' error - ')),
      reason: 'no analyzer errors allowed in generated view output:\n$output',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
