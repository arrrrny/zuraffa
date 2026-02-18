import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';

void main() {
  late String tempDir;
  late ControllerPlugin controllerPlugin;
  late PresenterPlugin presenterPlugin;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('custom_usecase_test');
    tempDir = dir.path;
    controllerPlugin = ControllerPlugin(
      outputDir: tempDir,
      dryRun: false,
      force: true,
      verbose: true,
    );
    presenterPlugin = PresenterPlugin(
      outputDir: tempDir,
      dryRun: false,
      force: true,
      verbose: true,
    );
  });

  tearDown(() async {
    await Directory(tempDir).delete(recursive: true);
  });

  test('Should add custom use case to Presenter and Controller', () async {
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get'], // Standard method initially
      generateController: true,
      generatePresenter: true,
      generateDi: true,
      outputDir: tempDir,
    );

    // 1. Generate initial files
    await presenterPlugin.generate(config);
    await controllerPlugin.generate(config);

    final presenterPath = path.join(
      tempDir,
      'presentation',
      'pages',
      'product',
      'product_presenter.dart',
    );
    final controllerPath = path.join(
      tempDir,
      'presentation',
      'pages',
      'product',
      'product_controller.dart',
    );

    expect(File(presenterPath).existsSync(), isTrue);
    expect(File(controllerPath).existsSync(), isTrue);

    // 2. Add custom use case
    final addConfig = GeneratorConfig(
      name: 'Product',
      methods: ['ActivateProduct'], // Custom use case
      generateController: true,
      generatePresenter: true,
      generateDi: true,
      outputDir: tempDir,
      verbose: true,
    );

    await presenterPlugin.add(addConfig);
    await controllerPlugin.add(addConfig);

    // 3. Verify Presenter
    final presenterContent = await File(presenterPath).readAsString();
    expect(presenterContent, contains('import \'../../../domain/usecases/product/activate_product_usecase.dart\';'));
    // Flexible check for field declaration
    expect(presenterContent, contains('late final ActivateProductUseCase _activateProduct'));
    expect(presenterContent, contains('registerUseCase'));
    expect(presenterContent, contains('getIt<ActivateProductUseCase>()'));
    
    expect(presenterContent, contains('Future<Result<void, AppFailure>> activateProduct() async {'));
    expect(presenterContent, contains('// TODO: Implement activateProduct'));

    // 4. Verify Controller
    final controllerContent = await File(controllerPath).readAsString();
    expect(controllerContent, contains('Future<void> activateProduct() async {'));
    // Flexible check for presenter call
    expect(controllerContent, contains('presenter.activateProduct();'));
  });

  test('Should remove custom use case from Presenter and Controller', () async {
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get'],
      generateController: true,
      generatePresenter: true,
      generateDi: true,
      outputDir: tempDir,
      action: PluginAction.create,
    );

    await presenterPlugin.generate(config);
    await controllerPlugin.generate(config);

    final addConfig = GeneratorConfig(
      name: 'Product',
      methods: ['ActivateProduct'],
      generateController: true,
      generatePresenter: true,
      generateDi: true,
      outputDir: tempDir,
      action: PluginAction.add,
      verbose: true,
    );

    await presenterPlugin.add(addConfig);
    await controllerPlugin.add(addConfig);

    // Verify added
    var presenterContent = await File(path.join(tempDir, 'presentation', 'pages', 'product', 'product_presenter.dart')).readAsString();
    expect(presenterContent, contains('activateProduct'));

    final removeConfig = GeneratorConfig(
      name: 'Product',
      methods: ['ActivateProduct'],
      generateController: true,
      generatePresenter: true,
      generateDi: true,
      outputDir: tempDir,
      action: PluginAction.remove,
      verbose: true,
    );
    
    await presenterPlugin.remove(removeConfig);
    await controllerPlugin.remove(removeConfig);

    // Verify removed
    presenterContent = await File(path.join(tempDir, 'presentation', 'pages', 'product', 'product_presenter.dart')).readAsString();
    expect(presenterContent, isNot(contains('activateProduct')));
    expect(presenterContent, isNot(contains('ActivateProductUseCase')));

    final controllerContent = await File(path.join(tempDir, 'presentation', 'pages', 'product', 'product_controller.dart')).readAsString();
    expect(controllerContent, isNot(contains('activateProduct')));
  });
}
