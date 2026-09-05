@Tags(['flutter'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';

import '../helpers/flutter_cluster_fixture.dart';

/// Spec 1003 (T002) — compile gate for the `presenter` trust-tier
/// generator.
///
/// Generates the presenter with the real plugin into a temp Flutter
/// project (plus entity/repository/usecase stubs), resolves packages with
/// `flutter pub get`, and asserts `flutter analyze` exits 0.
///
/// Tagged `flutter`: runs in the CI flutter lane, excluded from the
/// pure-Dart lane.
void main() {
  late Directory projectRoot;
  late String flutterExe;

  setUpAll(() async {
    projectRoot = await createFlutterClusterFixture('presenter_compile');
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

  test('generated presenter passes flutter analyze (exit 0)', () async {
    final files =
        await PresenterPlugin(
          outputDir: projectRoot.path,
          options: const GeneratorOptions(dryRun: false, force: true),
        ).generate(
          GeneratorConfig(
            name: 'Product',
            methods: ['get'],
            generatePresenter: true,
            outputDir: projectRoot.path,
          ),
        );
    expect(files, hasLength(1));

    final presenterFile = File(
      p.join(
        projectRoot.path,
        'presentation',
        'pages',
        'product',
        'product_presenter.dart',
      ),
    );
    expect(presenterFile.existsSync(), isTrue);

    final result = await Process.run(flutterExe, [
      'analyze',
      '--no-fatal-warnings',
      p.join('presentation', 'pages', 'product'),
    ], workingDirectory: projectRoot.path);
    final output = '${result.stdout}${result.stderr}';

    expect(
      result.exitCode,
      0,
      reason: 'generated presenter must analyze clean. Output:\n$output',
    );
    expect(
      output,
      isNot(contains(' error - ')),
      reason:
          'no analyzer errors allowed in generated presenter output:\n'
          '$output',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
