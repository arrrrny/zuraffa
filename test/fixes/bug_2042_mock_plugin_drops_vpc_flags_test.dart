import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

/// Bug 2042 — the #2040 fix (`88c01e25`, emit the mock data fixture in
/// presentation-only VPC generation) patched `MockBuilder`, but the
/// invocation path `CodeGenerator` drives never reaches the patched guard
/// with the VPC flags intact.
///
/// `PluginManager.run` routes every `FileGeneratorPlugin` through
/// `generateWithContext(context)`, and `MockPlugin.generateWithContext`
/// rebuilds a fresh `GeneratorConfig` from a fixed key list of the plugin
/// context. `CodeGenerator` serializes the caller's full config into that
/// context (`buildPluginOptions(config.toJson())`), so the VPC flags ARE
/// present — as the short JSON keys `vpcs` / `view` / `presenter` /
/// `controller` / `state` — but the rebuild never reads them, so they
/// default to `false`. MockBuilder's `isVpc` guard then sees a
/// presentation-only config as non-VPC, `isCustomUseCase` is true
/// (`methods: []`), and the fixture emission takes the honest `skipped`
/// branch: `data/mock/<entity>_mock_data.dart` is not written.
///
/// The direct-`MockBuilder` #2040 test passes because it skips the plugin
/// pipeline entirely — this test mirrors what `zuraffa_flutter`'s
/// presentation-only VPC workflow exercises (`test/vpc/
/// presentation_only_workflow_vpc_test.dart`) and fails until the rebuild
/// carries the five VPC flags.
void main() {
  /// Runs one fresh-workspace, CodeGenerator-driven presentation-only VPC
  /// case (only the given VPC flags plus generateMock are on) and asserts
  /// the mock data fixture is emitted.
  Future<void> expectMockFixtureEmitted({
    bool generateVpcs = false,
    bool generateView = false,
    bool generatePresenter = false,
    bool generateController = false,
    bool generateState = false,
    bool generateDi = false,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('zuraffa_2042_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    final outputDir = p.join(tempDir.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    // This pubspec is never resolved by pub — generation runs fully
    // in-process, and the only consumer is the view/presenter/controller
    // engine-purity check, which looks for the `flutter:` key (absent here,
    // hence the "pure-Dart package" skip warnings in a passing run). The
    // `git:` dependency block and the SDK floor are inert.
    await File(p.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: demo
environment:
  sdk: ">=3.11.0 <4.0.0"
dependencies:
  zuraffa:
    git:
      url: https://github.com/arrrrny/zuraffa
''');

    final config = GeneratorConfig(
      name: 'Profile',
      methods: const [], // presentation-only: non-entity based
      generateVpcs: generateVpcs,
      generateView: generateView,
      generatePresenter: generatePresenter,
      generateController: generateController,
      generateState: generateState,
      generateMock: true, // enabled by default in zfa.json
      generateDi: generateDi, // enabled by default in zfa.json
      generateUseCase: false,
      generateRepository: false,
      generateDataSource: false,
      generateData: false,
      outputDir: outputDir,
    );

    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
      disabledPluginIds: {'usecase', 'repository', 'datasource', 'provider'},
    );

    final result = await generator.generate();

    expect(result.success, isTrue);
    expect(
      File(
        p.join(outputDir, 'data', 'mock', 'profile_mock_data.dart'),
      ).existsSync(),
      isTrue,
      reason:
          'generateMock is on and the request is presentation-only VPC — '
          'the mock data fixture is emitted (#770 / #2040)',
    );
  }

  test(
    'bug 2042: CodeGenerator-driven presentation-only VPC run emits the mock data fixture',
    () => expectMockFixtureEmitted(
      generateVpcs: true,
      generateView: true,
      generatePresenter: true,
      generateController: true,
      generateState: true,
      generateDi: true,
    ),
  );

  // Isolated single-flag cases: the all-flags case above cannot detect the
  // loss of one forwarded key (the remaining four still flip MockBuilder's
  // isVpc OR-guard), so each key the `MockPlugin.generateWithContext` rebuild
  // must carry gets its own fresh-workspace case where it is the only VPC
  // flag set.
  test(
    'bug 2042: isolated vpcs flag alone emits the mock data fixture',
    () => expectMockFixtureEmitted(generateVpcs: true),
  );
  test(
    'bug 2042: isolated view flag alone emits the mock data fixture',
    () => expectMockFixtureEmitted(generateView: true),
  );
  test(
    'bug 2042: isolated presenter flag alone emits the mock data fixture',
    () => expectMockFixtureEmitted(generatePresenter: true),
  );
  test(
    'bug 2042: isolated controller flag alone emits the mock data fixture',
    () => expectMockFixtureEmitted(generateController: true),
  );
  test(
    'bug 2042: isolated state flag alone emits the mock data fixture',
    () => expectMockFixtureEmitted(generateState: true),
  );
}
