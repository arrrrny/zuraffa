import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_controller_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates stateful controller with cancel tokens', () async {
    final plugin = ControllerPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Product',
      methods: const ['get', 'watchList'],
      generateController: true,
      generateState: true,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(
      content.contains('class ProductController extends Controller'),
      isTrue,
    );
    expect(content.contains('StatefulController<ProductState>'), isTrue);
    expect(content.contains('createInitialState()'), isTrue);
    expect(content.contains('createCancelToken()'), isTrue);
    expect(content.contains('registerSubscription'), isTrue);
  });

  test('generates stateless controller without viewState', () async {
    final plugin = ControllerPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Order',
      methods: const ['get', 'delete'],
      generateController: true,
      generateState: false,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(
      content.contains('class OrderController extends Controller'),
      isTrue,
    );
    expect(content.contains('viewState'), isFalse);
  });
}
