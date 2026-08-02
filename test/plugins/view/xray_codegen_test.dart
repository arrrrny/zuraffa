import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_xray_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates view with XRayScope and node enum when xray enabled',
      () async {
    final plugin = ViewPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'Product',
      methods: const ['get', 'update'],
      generateView: true,
      generateXRay: true,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    expect(files, isNotEmpty);

    final content =
        files.firstWhere((f) => f.path.contains('product_view.dart')).content ??
            '';

    // Must contain XRayScope wrapper
    expect(content.contains('XRayScope('), isTrue);
    expect(content.contains("viewId: 'ProductView'"), isTrue);

    // Must contain the node enum
    expect(content.contains('enum ProductViewNode'), isTrue);
    expect(content.contains('actionButton'), isTrue);

    // Must contain XRayNode wrapping
    expect(content.contains('XRayNode<'), isTrue);
    expect(content.contains('ProductViewNode.actionButton'), isTrue);
  });

  test('generates view without XRayScope when xray disabled (default)',
      () async {
    final plugin = ViewPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'Product',
      methods: const ['get', 'update'],
      generateView: true,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    expect(files, isNotEmpty);
    final content =
        files.firstWhere((f) => f.path.contains('product_view.dart')).content ??
            '';

    // Should NOT contain XRay
    expect(content.contains('XRayScope'), isFalse);
    expect(content.contains('XRayNode'), isFalse);
    expect(content.contains('ProductViewNode'), isFalse);
  });
}
