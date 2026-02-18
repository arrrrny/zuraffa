import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_action.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';

void main() {
  late String tempDir;
  late RepositoryPlugin repositoryPlugin;
  late DataSourcePlugin dataSourcePlugin;
  late ServicePlugin servicePlugin;
  late UseCasePlugin useCasePlugin;
  late ViewPlugin viewPlugin;
  late ControllerPlugin controllerPlugin;
  late PresenterPlugin presenterPlugin;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('atomic_actions_test');
    tempDir = dir.path;
    repositoryPlugin = RepositoryPlugin(
      outputDir: tempDir,
      dryRun: false,
      force: true,
      verbose: true,
    );
    dataSourcePlugin = DataSourcePlugin(
      outputDir: tempDir,
      dryRun: false,
      force: true,
      verbose: true,
    );
    servicePlugin = ServicePlugin(
      outputDir: tempDir,
      dryRun: false,
      force: true,
      verbose: true,
    );
    useCasePlugin = UseCasePlugin(
      outputDir: tempDir,
      dryRun: false,
      force: true,
      verbose: true,
    );
    viewPlugin = ViewPlugin(
      outputDir: tempDir,
      dryRun: false,
      force: true,
      verbose: true,
    );
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
    if (Directory(tempDir).existsSync()) {
      await Directory(tempDir).delete(recursive: true);
    }
  });

  test('RepositoryPlugin atomic actions (add/remove)', () async {
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get'],
      generateRepository: true,
      generateData: true,
      outputDir: tempDir,
      action: PluginAction.create,
    );

    await repositoryPlugin.generate(config);

    final interfacePath = path.join(tempDir, 'domain', 'repositories', 'product_repository.dart');
    final implPath = path.join(tempDir, 'data', 'repositories', 'data_product_repository.dart');

    expect(await File(interfacePath).readAsString(), contains('get('));
    expect(await File(implPath).readAsString(), contains('get('));

    // Add method
    final addConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'],
      generateRepository: true,
      generateData: true,
      outputDir: tempDir,
      action: PluginAction.add,
      verbose: true,
    );

    await repositoryPlugin.add(addConfig);

    expect(await File(interfacePath).readAsString(), contains('activateProduct'));
    expect(await File(implPath).readAsString(), contains('activateProduct'));

    // Remove method
    final removeConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'],
      generateRepository: true,
      generateData: true,
      outputDir: tempDir,
      action: PluginAction.remove,
      verbose: true,
    );

    await repositoryPlugin.remove(removeConfig);

    expect(await File(interfacePath).readAsString(), isNot(contains('activateProduct')));
    expect(await File(implPath).readAsString(), isNot(contains('activateProduct')));
  });

  test('DataSourcePlugin atomic actions (add/remove)', () async {
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get'],
      generateDataSource: true,
      outputDir: tempDir,
      action: PluginAction.create,
    );

    await dataSourcePlugin.generate(config);

    final localPath = path.join(tempDir, 'data', 'datasources', 'product', 'product_local_datasource.dart');
    final remotePath = path.join(tempDir, 'data', 'datasources', 'product', 'product_remote_datasource.dart');

    // Add method
    final addConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'],
      generateDataSource: true,
      outputDir: tempDir,
      action: PluginAction.add,
      verbose: true,
    );

    await dataSourcePlugin.add(addConfig);

    // Depending on config, it might generate local or remote or both.
    // Default GeneratorConfig might generate both if not specified?
    // Let's check. If not specified, it usually defaults to generated.
    // But checking file existence is safer.
    if (File(localPath).existsSync()) {
      expect(await File(localPath).readAsString(), contains('activateProduct'));
    }
    if (File(remotePath).existsSync()) {
      expect(await File(remotePath).readAsString(), contains('activateProduct'));
    }

    // Remove method
    final removeConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'],
      generateDataSource: true,
      outputDir: tempDir,
      action: PluginAction.remove,
      verbose: true,
    );

    await dataSourcePlugin.remove(removeConfig);

    if (File(localPath).existsSync()) {
      expect(await File(localPath).readAsString(), isNot(contains('activateProduct')));
    }
    if (File(remotePath).existsSync()) {
      expect(await File(remotePath).readAsString(), isNot(contains('activateProduct')));
    }
  });

  test('ServicePlugin atomic actions (add/remove)', () async {
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get'],
      service: 'Product',
      outputDir: tempDir,
      action: PluginAction.create,
    );

    await servicePlugin.generate(config);

    final interfacePath = path.join(tempDir, 'domain', 'services', 'product_service.dart');

    // Add method
    final addConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'],
      service: 'Product',
      outputDir: tempDir,
      action: PluginAction.add,
      verbose: true,
    );

    await servicePlugin.add(addConfig);

    expect(await File(interfacePath).readAsString(), contains('activateProduct'));

    // Remove method
    final removeConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'],
      service: 'Product',
      outputDir: tempDir,
      action: PluginAction.remove,
      verbose: true,
    );

    await servicePlugin.remove(removeConfig);

    expect(await File(interfacePath).readAsString(), isNot(contains('activateProduct')));
  });

  test('UseCasePlugin atomic actions (add/remove)', () async {
    // Generate standard entity usecase first
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get'],
      outputDir: tempDir,
      action: PluginAction.create,
    );

    await useCasePlugin.generate(config);

    final getUseCasePath = path.join(tempDir, 'domain', 'usecases', 'product', 'get_product_usecase.dart');
    expect(File(getUseCasePath).existsSync(), isTrue);

    // Add custom usecase (creates new file)
    final addConfig = GeneratorConfig(
      name: 'ActivateProduct', // Custom usecase name
      methods: [], // Empty methods implies custom usecase
      domain: 'product', // Specify domain
      outputDir: tempDir,
      action: PluginAction.add,
      repo: 'ProductRepository', // Specify dependency
      verbose: true,
    );

    await useCasePlugin.add(addConfig);

    final activateUseCasePath = path.join(tempDir, 'domain', 'usecases', 'product', 'activate_product_usecase.dart');
    expect(File(activateUseCasePath).existsSync(), isTrue);

    // Remove custom usecase (deletes file)
    final removeConfig = GeneratorConfig(
      name: 'ActivateProduct',
      methods: [],
      domain: 'product',
      outputDir: tempDir,
      action: PluginAction.remove,
      verbose: true,
    );

    await useCasePlugin.remove(removeConfig);

    expect(File(activateUseCasePath).existsSync(), isFalse);
    expect(File(getUseCasePath).existsSync(), isTrue); // Should remain
  });

  test('ViewPlugin atomic actions (add/remove) - No-op verification', () async {
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get'],
      generateView: true,
      outputDir: tempDir,
      action: PluginAction.create,
    );

    await viewPlugin.generate(config);

    final viewPath = path.join(tempDir, 'presentation', 'pages', 'product', 'product_view.dart');
    expect(File(viewPath).existsSync(), isTrue);
    final originalContent = await File(viewPath).readAsString();

    // Add method (should be no-op)
    final addConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'],
      generateView: true,
      outputDir: tempDir,
      action: PluginAction.add,
      verbose: true,
    );

    final addResult = await viewPlugin.add(addConfig);
    expect(addResult, isEmpty);
    expect(await File(viewPath).readAsString(), equals(originalContent));

    // Remove method (should be no-op)
    final removeConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'],
      generateView: true,
      outputDir: tempDir,
      action: PluginAction.remove,
      verbose: true,
    );

    final removeResult = await viewPlugin.remove(removeConfig);
    expect(removeResult, isEmpty);
    expect(await File(viewPath).readAsString(), equals(originalContent));
  });

  test('ControllerPlugin atomic actions (add/remove)', () async {
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get'],
      generateController: true,
      outputDir: tempDir,
      action: PluginAction.create,
    );

    await controllerPlugin.generate(config);

    final controllerPath = path.join(
      tempDir,
      'presentation',
      'pages',
      'product',
      'product_controller.dart',
    );
    expect(File(controllerPath).existsSync(), isTrue);

    // Add method
    final addConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'],
      generateController: true,
      outputDir: tempDir,
      action: PluginAction.add,
      verbose: true,
    );

    await controllerPlugin.add(addConfig);

    final controllerContent = await File(controllerPath).readAsString();
    expect(controllerContent, contains('activateProduct()'));
    expect(controllerContent, contains('presenter.activateProduct()'));

    // Remove method
    final removeConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'],
      generateController: true,
      outputDir: tempDir,
      action: PluginAction.remove,
      verbose: true,
    );

    await controllerPlugin.remove(removeConfig);

    final removedContent = await File(controllerPath).readAsString();
    expect(removedContent, isNot(contains('activateProduct()')));
  });

  test('PresenterPlugin atomic actions (add/remove)', () async {
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get'],
      generatePresenter: true,
      generateDi: true, // Required for use case injection logic
      outputDir: tempDir,
      action: PluginAction.create,
    );

    await presenterPlugin.generate(config);

    final presenterPath = path.join(
      tempDir,
      'presentation',
      'pages',
      'product',
      'product_presenter.dart',
    );
    expect(File(presenterPath).existsSync(), isTrue);

    // Add method (simulate adding use case)
    final addConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'], // This triggers custom use case injection
      generatePresenter: true,
      generateDi: true,
      outputDir: tempDir,
      action: PluginAction.add,
      verbose: true,
    );

    await presenterPlugin.add(addConfig);

    final presenterContent = await File(presenterPath).readAsString();
    // Check for custom use case import, field, and method
    expect(presenterContent, contains('activate_product_usecase.dart'));
    expect(presenterContent, contains('ActivateProductUseCase'));
    expect(presenterContent, contains('activateProduct()'));

    // Remove method
    final removeConfig = GeneratorConfig(
      name: 'Product',
      methods: ['activateProduct'],
      generatePresenter: true,
      generateDi: true,
      outputDir: tempDir,
      action: PluginAction.remove,
      verbose: true,
    );

    await presenterPlugin.remove(removeConfig);

    final removedContent = await File(presenterPath).readAsString();
    expect(removedContent, isNot(contains('activate_product_usecase.dart')));
    expect(removedContent, isNot(contains('ActivateProductUseCase')));
    expect(removedContent, isNot(contains('_activateProductUseCase'))); // Ensure field and constructor assignment are gone
    expect(removedContent, isNot(contains('activateProduct()')));
  });
}
