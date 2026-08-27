@Tags(['integration', 'slow'])
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('full_entity_workflow');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    await writeEntityStub(workspace, name: 'Product');
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'generates full entity workflow',
    timeout: Timeout(Duration(minutes: 5)),
    () async {
      final config = GeneratorConfig(
        name: 'Product',
        methods: const [
          'get',
          'getList',
          'create',
          'update',
          'delete',
          'watchList',
        ],
        generateData: true,
        generateVpcs: true,
        generateState: true,
        generateDi: true,
        generateMock: true,
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
      );

      final result = await generator.generate();

      expect(result.success, isTrue);
      expect(
        File(
          '$outputDir/domain/repositories/product_repository.dart',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '$outputDir/data/repositories/data_product_repository.dart',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '$outputDir/data/datasources/product/product_datasource.dart',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '$outputDir/data/datasources/product/product_remote_datasource.dart',
        ).existsSync(),
        isTrue,
      );
      // This workspace is a *pure-Dart* fixture (the pubspec written by
      // `writePubspec` declares no `flutter:` SDK), so per Constitution VII
      // (Engine Purity) the view/controller/presenter generators correctly
      // SKIP output for a pure-Dart target (see #420): those artifacts
      // depend on `zuraffa_flutter`, which is unavailable here. The full
      // entity workflow's VPC output (view + controller + presenter) is
      // verified in the `zuraffa_flutter` package — see issues #431 / #435.
      expect(
        File(
          '$outputDir/presentation/pages/product/product_view.dart',
        ).existsSync(),
        isFalse,
        reason:
            'pure-Dart target must NOT generate a Flutter view '
            '(Constitution VII: Engine Purity)',
      );
      expect(
        File(
          '$outputDir/presentation/pages/product/product_controller.dart',
        ).existsSync(),
        isFalse,
        reason:
            'pure-Dart target must NOT generate a Flutter controller '
            '(Constitution VII: Engine Purity)',
      );
      expect(
        File(
          '$outputDir/presentation/pages/product/product_presenter.dart',
        ).existsSync(),
        isFalse,
        reason:
            'pure-Dart target must NOT generate a Flutter presenter '
            '(Constitution VII: Engine Purity)',
      );
      expect(
        File(
          '$outputDir/presentation/pages/product/product_state.dart',
        ).existsSync(),
        isTrue,
      );
    },
  );
}
