import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/route/builders/route_builder.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_route_deps_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('omits repository injection when DI is enabled', () async {
    final builder = RouteBuilder(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    await builder.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateRoute: true,
        generateDi: true,
      ),
    );

    final entityRoutes = File('$outputDir/routing/product_routes.dart');
    final content = entityRoutes.readAsStringSync();
    expect(content.contains('getIt'), isFalse);
    expect(content.contains('service_locator.dart'), isFalse);
    expect(content.contains('const ProductView()'), isTrue);
  });

  test('detail routes omit id when id type is NoParams', () async {
    final builder = RouteBuilder(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    await builder.generate(
      GeneratorConfig(
        name: 'Health',
        methods: const ['get'],
        generateRoute: true,
        idType: 'NoParams',
      ),
    );

    final entityRoutes = File('$outputDir/routing/health_routes.dart');
    final content = entityRoutes.readAsStringSync();
    expect(content.contains('pathParameters'), isFalse);
    expect(content.contains('HealthRepository'), isTrue);
  });
}
