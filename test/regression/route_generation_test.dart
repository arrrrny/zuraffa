import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/plugins/route/builders/route_builder.dart';
import 'package:zuraffa/src/models/generator_config.dart';

void main() {
  test('routes generate valid go_router configs', () async {
    final dir = await Directory.systemTemp.createTemp('zuraffa_routes_');
    final outputDir = '${dir.path}/lib/src';
    final generator = RouteBuilder(
      outputDir: outputDir,
      force: true,
      dryRun: false,
      verbose: false,
    );
    final files = await generator.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'create', 'update'],
        generateView: true,
      ),
    );
    final content = files.map((f) => f.content ?? '').join('\n');
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
