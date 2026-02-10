import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/generator/route_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

void main() {
  test('routes generate valid go_router configs', () async {
    final dir = await Directory.systemTemp.createTemp('zuraffa_routes_');
    final outputDir = '${dir.path}/lib/src';
    final generator = RouteGenerator(
      config: GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'update'],
        generateView: true,
      ),
      outputDir: outputDir,
      force: true,
      dryRun: false,
      verbose: false,
    );
    final files = await generator.generate();
    final content = files.first.content ?? '';
    expect(content.contains("'/product'"), isTrue);
    expect(content.contains("'/product/:id'"), isTrue);
    expect(content.contains("'/product/create'"), isTrue);
    expect(content.contains("'/product/:id/edit'"), isTrue);
    expect(content.contains('GoRoute('), isTrue);

    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });
}
