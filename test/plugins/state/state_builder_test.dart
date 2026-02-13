import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/state/builders/state_builder.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_state_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates state with fields and helpers', () async {
    final builder = StateBuilder(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    final file = await builder.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'getList', 'create'],
        generateState: true,
      ),
    );

    expect(file.path.endsWith('product_state.dart'), isTrue);
    final content = File(file.path).readAsStringSync();
    expect(content.contains('class ProductState'), isTrue);
    expect(content.contains('isGetting'), isTrue);
    expect(content.contains('copyWith'), isTrue);
  });
}
