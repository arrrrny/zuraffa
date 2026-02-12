import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/route/builders/route_builder.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_route_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates app routes and entity routes', () async {
    final builder = RouteBuilder(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'getList', 'create'],
        generateVpc: true,
        generateRoute: true,
      ),
    );

    expect(files.length, equals(2));
    final appRoutes = File('$outputDir/routing/app_routes.dart');
    final entityRoutes = File('$outputDir/routing/product_routes.dart');
    expect(appRoutes.existsSync(), isTrue);
    expect(entityRoutes.existsSync(), isTrue);
    final content = entityRoutes.readAsStringSync();
    expect(content.contains('/product'), isTrue);
    expect(content.contains('/product/create'), isTrue);
  });
}
