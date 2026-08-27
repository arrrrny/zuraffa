// Transported from the pure-Dart `zuraffa` core package (issue #431).
//
// Integration coverage for the full entity workflow's VPC layer. The core's
// `test/integration/full_entity_workflow_test.dart` runs against a *pure-Dart*
// fixture, where VPC generation is now correctly skipped (Constitution VII:
// Engine Purity, see #420) — so the view/controller/presenter assertions were
// transported into THIS package where the fixture pubspec declares
// `flutter:` and the VPC generators actually run. The core keeps the
// domain/data/state assertions (repository, data repository, datasources,
// state) and the VPC skip assertions.
//
// See: test/integration/full_entity_workflow_test.dart (core),
// https://github.com/arrrrny/zuraffa/issues/431.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import 'vpc_test_utils.dart';

void main() {
  late VpcWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('full_entity_vpc_');
    await writeFlutterPubspec(workspace);
    await writeEntityStub(workspace, name: 'Product');
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'generates full entity workflow — VPC layer (Flutter target)',
    timeout: const Timeout(Duration(minutes: 5)),
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
      // The fixture pubspec declares `flutter:`, so the VPC generators run
      // (they are skipped only for pure-Dart targets, see #420).
      expect(
        File(
          '$outputDir/presentation/pages/product/product_view.dart',
        ).existsSync(),
        isTrue,
        reason: 'product_view.dart should be generated for a Flutter target',
      );
      expect(
        File(
          '$outputDir/presentation/pages/product/product_controller.dart',
        ).existsSync(),
        isTrue,
        reason:
            'product_controller.dart should be generated for a Flutter target',
      );
      expect(
        File(
          '$outputDir/presentation/pages/product/product_presenter.dart',
        ).existsSync(),
        isTrue,
        reason:
            'product_presenter.dart should be generated for a Flutter target',
      );
      expect(
        File(
          '$outputDir/presentation/pages/product/product_state.dart',
        ).existsSync(),
        isTrue,
        reason: 'product_state.dart should be generated',
      );
    },
  );
}
