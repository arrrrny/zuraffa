@Tags(['flutter'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';

import '../helpers/flutter_cluster_fixture.dart';

/// Spec 1003 (T002) — compile gate for the `controller` trust-tier
/// generator.
///
/// Generates controller + presenter with the real plugins into a temp
/// Flutter project (plus entity/repository/usecase stubs), resolves
/// packages with `flutter pub get`, and asserts `flutter analyze` exits 0.
///
/// Tagged `flutter`: runs in the CI flutter lane, excluded from the
/// pure-Dart lane.
void main() {
  late Directory projectRoot;
  late String flutterExe;

  setUpAll(() async {
    projectRoot = await createFlutterClusterFixture('controller_compile');
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

  test('generated controller passes flutter analyze (exit 0)', () async {
    const opts = GeneratorOptions(dryRun: false, force: true);

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

    final controllerFile = File(
      p.join(
        projectRoot.path,
        'presentation',
        'pages',
        'product',
        'product_controller.dart',
      ),
    );
    expect(controllerFile.existsSync(), isTrue);

    final result = await Process.run(flutterExe, [
      'analyze',
      '--no-fatal-warnings',
      p.join('presentation', 'pages', 'product'),
    ], workingDirectory: projectRoot.path);
    final output = '${result.stdout}${result.stderr}';

    expect(
      result.exitCode,
      0,
      reason: 'generated controller must analyze clean. Output:\n$output',
    );
    expect(
      output,
      isNot(contains(' error - ')),
      reason:
          'no analyzer errors allowed in generated controller output:\n'
          '$output',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
