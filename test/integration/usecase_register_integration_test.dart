import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';
import 'package:zuraffa/src/plugins/presenter/capabilities/register_presenter_capability.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';
import 'package:zuraffa/src/plugins/controller/capabilities/register_controller_capability.dart';
import 'package:zuraffa/src/plugins/state/state_plugin.dart';
import 'package:zuraffa/src/plugins/state/capabilities/register_state_capability.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('usecase_register');
    await writePubspec(workspace);
    await writeEntityStub(workspace, name: 'Product');
    await writeMainStub(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  group('RegisterPresenterCapability', () {
    test('registers a new use case in an existing presenter', () async {
      // First, generate a presenter with initial use cases
      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'Product',
          methods: const ['get', 'getList', 'create'],
          generatePresenter: true,
          generateDi: true,
          outputDir: outputDir,
        ),
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final result = await generator.generate();
      expect(result.success, isTrue);

      final presenterPath =
          '$outputDir/presentation/pages/product/product_presenter.dart';
      final presenterFile = File(presenterPath);
      expect(presenterFile.existsSync(), isTrue);

      // Read initial content
      final initialContent = presenterFile.readAsStringSync();
      expect(initialContent.contains('GetProductUseCase'), isTrue);
      expect(initialContent.contains('DeleteProductUseCase'), isFalse);

      // Now register a new use case via the capability
      final plugin = PresenterPlugin(outputDir: outputDir);
      final capability = RegisterPresenterCapability(plugin);

      final execResult = await capability.execute({
        'target': 'DeleteProduct',
        'domain': 'product',
        'force': true,
        'verbose': false,
      });

      expect(execResult.success, isTrue);

      // Verify the presenter file was updated
      final updatedContent = presenterFile.readAsStringSync();
      expect(updatedContent.contains('DeleteProductUseCase'), isTrue);
      expect(updatedContent.contains('_deleteProduct'), isTrue);
      expect(
        updatedContent.contains(
          'registerUseCase(getIt<DeleteProductUseCase>())',
        ),
        isTrue,
      );

      // Verify existing use cases are preserved
      expect(updatedContent.contains('GetProductUseCase'), isTrue);
      expect(updatedContent.contains('CreateProductUseCase'), isTrue);

      // Verify it still compiles (if dart analyze is available)
      // final analyzeResult = await runDartAnalyze(workspace);
      // expect(analyzeResult.exitCode, equals(0));
    });

    test('dry-run does not modify the file', () async {
      // Generate a presenter
      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'Order',
          methods: const ['get'],
          generatePresenter: true,
          generateDi: true,
          outputDir: outputDir,
        ),
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      await generator.generate();

      final presenterPath =
          '$outputDir/presentation/pages/order/order_presenter.dart';
      final presenterFile = File(presenterPath);
      final contentBefore = presenterFile.readAsStringSync();

      // Run in dry-run mode
      final plugin = PresenterPlugin(outputDir: outputDir);
      final capability = RegisterPresenterCapability(plugin);

      final execResult = await capability.execute({
        'target': 'UpdateOrder',
        'domain': 'order',
        'dryRun': true,
        'force': true,
      });

      expect(execResult.success, isTrue);

      // Verify the file was NOT modified
      final contentAfter = presenterFile.readAsStringSync();
      expect(contentAfter, equals(contentBefore));
    });

    test('returns error when presenter file does not exist', () async {
      final plugin = PresenterPlugin(outputDir: outputDir);
      final capability = RegisterPresenterCapability(plugin);

      final execResult = await capability.execute({
        'target': 'GetProduct',
        'domain': 'nonexistent',
        'force': true,
      });

      expect(execResult.success, isFalse);
      expect(execResult.message, contains('Presenter file not found'));
    });
  });

  group('RegisterControllerCapability', () {
    test('registers a use case in an existing controller', () async {
      // Generate a controller
      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          generateController: true,
          generateDi: true,
          outputDir: outputDir,
        ),
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final result = await generator.generate();
      expect(result.success, isTrue);

      final controllerPath =
          '$outputDir/presentation/pages/product/product_controller.dart';
      final controllerFile = File(controllerPath);
      expect(controllerFile.existsSync(), isTrue);

      // Register a new use case
      final plugin = ControllerPlugin(outputDir: outputDir);
      final capability = RegisterControllerCapability(plugin);

      final execResult = await capability.execute({
        'target': 'CreateProduct',
        'domain': 'product',
        'force': true,
      });

      expect(execResult.success, isTrue);

      final updatedContent = controllerFile.readAsStringSync();
      expect(updatedContent.contains('CreateProductUseCase'), isTrue);
      expect(updatedContent.contains('_createProduct'), isTrue);
    });
  });

  group('RegisterStateCapability', () {
    test('registers a field in an existing state class', () async {
      // Generate a state class
      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          generateState: true,
          outputDir: outputDir,
        ),
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final result = await generator.generate();
      expect(result.success, isTrue);

      final statePath =
          '$outputDir/presentation/pages/product/product_state.dart';
      final stateFile = File(statePath);
      expect(stateFile.existsSync(), isTrue);

      final initialContent = stateFile.readAsStringSync();
      expect(initialContent.contains('selectedProduct'), isFalse);

      // Register a new field
      final plugin = StatePlugin(outputDir: outputDir);
      final capability = RegisterStateCapability(plugin);

      final execResult = await capability.execute({
        'target': 'selectedProduct',
        'type': 'Product?',
        'domain': 'product',
        'force': true,
      });

      expect(execResult.success, isTrue);

      final updatedContent = stateFile.readAsStringSync();
      expect(updatedContent.contains('Product?'), isTrue);
      expect(updatedContent.contains('selectedProduct'), isTrue);
    });
  });

  group('End-to-end workflow', () {
    test(
      'full VPC stack: register use case in presenter + controller',
      () async {
        // 1. Generate full VPC stack
        final generator = CodeGenerator(
          config: GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'getList'],
            generatePresenter: true,
            generateController: true,
            generateState: true,
            generateView: true,
            generateDi: true,
            outputDir: outputDir,
          ),
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final result = await generator.generate();
        expect(result.success, isTrue);

        // 2. Register a use case in the presenter
        final presenterPlugin = PresenterPlugin(outputDir: outputDir);
        final presenterCap = RegisterPresenterCapability(presenterPlugin);
        var capResult = await presenterCap.execute({
          'target': 'CreateProduct',
          'domain': 'product',
          'force': true,
        });
        expect(capResult.success, isTrue);

        // 3. Register the same use case in the controller
        final controllerPlugin = ControllerPlugin(outputDir: outputDir);
        final controllerCap = RegisterControllerCapability(controllerPlugin);
        capResult = await controllerCap.execute({
          'target': 'CreateProduct',
          'domain': 'product',
          'force': true,
        });
        expect(capResult.success, isTrue);

        // 4. Verify presenter
        final presenterContent = File(
          '$outputDir/presentation/pages/product/product_presenter.dart',
        ).readAsStringSync();
        expect(presenterContent.contains('CreateProductUseCase'), isTrue);
        expect(presenterContent.contains('_createProduct'), isTrue);
        expect(
          presenterContent.contains(
            'registerUseCase(getIt<CreateProductUseCase>())',
          ),
          isTrue,
        );

        // 5. Verify controller
        final controllerContent = File(
          '$outputDir/presentation/pages/product/product_controller.dart',
        ).readAsStringSync();
        expect(controllerContent.contains('CreateProductUseCase'), isTrue);
        expect(controllerContent.contains('_createProduct'), isTrue);

        // 6. Verify existing use cases preserved in presenter
        expect(presenterContent.contains('GetProductUseCase'), isTrue);
        expect(presenterContent.contains('GetProductListUseCase'), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });

  group('Edge cases', () {
    test('registering same use case twice is idempotent', () async {
      // Generate a presenter
      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'Product',
          methods: const ['get'],
          generatePresenter: true,
          generateDi: true,
          outputDir: outputDir,
        ),
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      await generator.generate();

      final plugin = PresenterPlugin(outputDir: outputDir);
      final capability = RegisterPresenterCapability(plugin);

      // First registration
      await capability.execute({
        'target': 'DeleteProduct',
        'domain': 'product',
        'force': true,
      });

      final contentAfterFirst = File(
        '$outputDir/presentation/pages/product/product_presenter.dart',
      ).readAsStringSync();

      // Second registration (should be no-op)
      await capability.execute({
        'target': 'DeleteProduct',
        'domain': 'product',
        'force': false,
      });

      final contentAfterSecond = File(
        '$outputDir/presentation/pages/product/product_presenter.dart',
      ).readAsStringSync();

      expect(contentAfterSecond, equals(contentAfterFirst));
    });
  });
}
