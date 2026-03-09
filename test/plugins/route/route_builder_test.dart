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
        generateVpcs: true,
        generateRoute: true,
        outputDir: outputDir,
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

  test('generates routes for custom usecase with domain', () async {
    final builder = RouteBuilder(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'GetListingByBarcode',
        domain: 'listing',
        paramsType: 'String',
        returnsType: 'Listing?',
        generateRoute: true,
        outputDir: outputDir,
      ),
    );

    expect(files.length, equals(2));
    final entityRoutes = File('$outputDir/routing/get_listing_by_barcode_routes.dart');
    expect(entityRoutes.existsSync(), isTrue);
    final content = entityRoutes.readAsStringSync();
    print('--- GENERATED ROUTE CONTENT ---\n$content\n-------------------------------');
    
    // Check path for custom usecase (should be just /get_listing_by_barcode)
    expect(content.contains("static const String getListingByBarcodeList = '/get_listing_by_barcode';"), isTrue);
    
    // Check view import with domain
    expect(content.contains("../presentation/pages/listing/get_listing_by_barcode_view.dart"), isTrue);
    
    // Check goRoute definition
    expect(content.contains("GoRoute("), isTrue);
    expect(content.contains("path: GetListingByBarcodeRoutes.getListingByBarcodeList"), isTrue);
    expect(content.contains("builder: (context, state) => const GetListingByBarcodeView()"), isTrue);
  });
}
