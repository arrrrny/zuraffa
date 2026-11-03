@Tags(['regression', 'slow'])
library;

// Regression test for issue #2042.
//
// The #2040 fix (88c01e25) taught `MockBuilder.generate` to emit the mock
// data fixture for presentation-only VPC generation instead of skipping it,
// but its guard reads the VPC flags off the `GeneratorConfig` it is handed.
// When the pipeline runs through `CodeGenerator` — the path zuraffa_flutter
// drives — `MockPlugin.generateWithContext` rebuilds that config from the
// `PluginContext` WITHOUT copying the five VPC flags
// (generateVpcs/generateView/generatePresenter/generateController/
// generateState), so they reach `MockBuilder` as their `false` defaults and
// the fixture is skipped again. Sibling plugins (view/presenter/controller/
// route) read these exact keys from `context.data`; the mock plugin now
// mirrors them.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import 'regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('issue_2042_mock_fixture_vpc');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test('issue #2042: CodeGenerator pipeline emits the mock data fixture for '
      'presentation-only VPC generation', () async {
    // The exact zuraffa_flutter configuration: generateMock plus all five
    // VPC flags true, methods empty (presentation-only), no Profile entity
    // on disk.
    final generator = CodeGenerator(
      config: GeneratorConfig(
        name: 'Profile',
        methods: const [],
        generateMock: true,
        generateVpcs: true,
        generateView: true,
        generatePresenter: true,
        generateController: true,
        generateState: true,
        outputDir: outputDir,
        dryRun: false,
        force: true,
      ),
      outputDir: outputDir,
    );

    final result = await generator.generate();

    expect(
      result.success,
      isTrue,
      reason: 'generation failed: ${result.errors}',
    );
    expect(
      File('$outputDir/data/mock/profile_mock_data.dart').existsSync(),
      isTrue,
    );
  });
}
