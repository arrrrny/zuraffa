import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_view_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates view with route params', () async {
    final plugin = ViewPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Product',
      methods: const ['get', 'update'],
      generateView: true,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    expect(files.isNotEmpty, isTrue);
    final content = files.first.content ?? '';
    expect(content.contains('class ProductView'), isTrue);
    expect(content.contains('final String? id'), isTrue);
    expect(content.contains('createState()'), isTrue);
  });

  test('generates view with query route param', () async {
    final plugin = ViewPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Product',
      methods: const ['get'],
      queryField: 'slug',
      queryFieldType: 'String',
      generateView: true,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(content.contains('final String? slug'), isTrue);
    expect(content.contains('widget.slug'), isTrue);
  });

  test('wires presenter and controller', () async {
    final plugin = ViewPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'Product',
      methods: const ['getList'],
      generateView: true,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(content.contains('ProductController('), isTrue);
    expect(content.contains('ProductPresenter('), isTrue);
    expect(content.contains('productRepository: productRepository'), isTrue);
  });
}
