import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:code_builder/code_builder.dart';
import 'package:zuraffa/src/plugins/route/builders/route_builder.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/route/builders/app_routes_builder.dart';
import 'package:zuraffa/src/plugins/route/builders/extension_builder.dart';

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

  test('updates app routes using AST append', () async {
    final routesDir = Directory('$outputDir/routing')
      ..createSync(recursive: true);
    final appRoutesPath = File('${routesDir.path}/app_routes.dart');

    final builder = AppRoutesBuilder();
    final initialContent = builder.buildFile(
      routes: {'home': '/'},
      extensionMethods: [
        ExtensionMethodSpec(
          name: 'goToHome',
          body: refer('go').call([refer('AppRoutes').property('home')]),
        ),
      ],
    );
    appRoutesPath.writeAsStringSync(initialContent);

    final generator = RouteBuilder(
      outputDir: outputDir,
      force: false,
      dryRun: false,
      verbose: false,
    );

    await generator.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'create'],
        generateView: true,
      ),
    );
    final updated = appRoutesPath.readAsStringSync();

    expect(updated.contains("static const String home = '/'"), isTrue);
    expect(updated.contains('goToHome'), isTrue);
    expect(
      updated.contains('static const String productList = \'/product\''),
      isTrue,
    );
    expect(updated.contains('goToProductList'), isTrue);
  });

  test('generates entity routes with go routes', () async {
    final generator = RouteBuilder(
      outputDir: outputDir,
      force: true,
      dryRun: false,
      verbose: false,
    );

    final files = await generator.generate(
      GeneratorConfig(
        name: 'Order',
        methods: const ['get', 'update'],
        generateView: true,
      ),
    );
    final entityFile = files.firstWhere(
      (f) => f.path.endsWith('order_routes.dart'),
    );
    final content = entityFile.content ?? '';

    expect(content.contains('abstract class OrderRoutes'), isTrue);
    expect(content.contains('List<GoRoute> getOrderRoutes'), isTrue);
    expect(content.contains('GoRoute('), isTrue);
    expect(content.contains('OrderView'), isTrue);
  });
}
