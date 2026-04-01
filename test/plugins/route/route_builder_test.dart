import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
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
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
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

    expect(files.length, equals(3));
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
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
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

    expect(files.length, equals(3));
    final entityRoutes = File('$outputDir/routing/listing_routes.dart');
    expect(entityRoutes.existsSync(), isTrue);
    final content = entityRoutes.readAsStringSync();

    // Check path for custom usecase (should be just /get_listing_by_barcode)
    expect(
      content.contains(
        "static const String getListingByBarcode = '/get_listing_by_barcode';",
      ),
      isTrue,
    );

    // Check view import with domain
    expect(
      content.contains(
        "../presentation/pages/listing/get_listing_by_barcode_view.dart",
      ),
      isTrue,
    );

    // Check goRoute definition
    expect(content.contains("GoRoute("), isTrue);
    expect(content.contains("path: ListingRoutes.getListingByBarcode"), isTrue);
  });

  test('generates standalone custom route', () async {
    final builder = RouteBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'Home',
        domain: 'general',
        methods: const [],
        generateRoute: true,
        outputDir: outputDir,
      ),
    );

    expect(files.length, equals(3));
    final entityRoutes = File('$outputDir/routing/general_routes.dart');
    expect(entityRoutes.existsSync(), isTrue);
    final content = entityRoutes.readAsStringSync();

    expect(content.contains("static const String home = '/home';"), isTrue);
    expect(
      content.contains("../presentation/pages/general/home_view.dart"),
      isTrue,
    );
    expect(content.contains("path: GeneralRoutes.home"), isTrue);
    expect(content.contains("HomeView()"), isTrue);
  });

  test('appends routes to existing domain routes file', () async {
    final builder = RouteBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    // 1. Generate first route
    await builder.generate(
      GeneratorConfig(
        name: 'GetListingByBarcode',
        domain: 'listing',
        paramsType: 'String',
        returnsType: 'Listing?',
        generateRoute: true,
        outputDir: outputDir,
      ),
    );

    // 2. Generate second route in same domain with append
    await builder.generate(
      GeneratorConfig(
        name: 'SearchListings',
        domain: 'listing',
        paramsType: 'String',
        returnsType: 'List<Listing>',
        generateRoute: true,
        appendToExisting: true,
        outputDir: outputDir,
      ),
    );

    final entityRoutes = File('$outputDir/routing/listing_routes.dart');
    expect(entityRoutes.existsSync(), isTrue);
    final content = entityRoutes.readAsStringSync();

    // Check both constants exist in the same class
    expect(
      content.contains('static const String getListingByBarcode ='),
      isTrue,
    );
    expect(content.contains('static const String searchListings ='), isTrue);

    // Check both routes exist in the same getter
    expect(content.contains('ListingRoutes.getListingByBarcode'), isTrue);
    expect(content.contains('ListingRoutes.searchListings'), isTrue);

    // Check both view imports
    expect(content.contains('get_listing_by_barcode_view.dart'), isTrue);
    expect(content.contains('search_listings_view.dart'), isTrue);
  });

  test('prevents duplicate routes when running twice', () async {
    final builder = RouteBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    final config = GeneratorConfig(
      name: 'GetListingByBarcode',
      domain: 'listing',
      paramsType: 'String',
      returnsType: 'Listing?',
      generateRoute: true,
      outputDir: outputDir,
    );

    // Run twice
    await builder.generate(config);
    await builder.generate(config);

    final entityRoutes = File('$outputDir/routing/listing_routes.dart');
    expect(entityRoutes.existsSync(), isTrue);
    final content = entityRoutes.readAsStringSync();

    // Count occurrences of the constant
    final constantMatches = 'static const String getListingByBarcode'
        .allMatches(content)
        .length;
    expect(
      constantMatches,
      equals(1),
      reason: 'Constant should not be duplicated',
    );

    // Count occurrences of GoRoute
    final routeMatches = 'GoRoute('.allMatches(content).length;
    expect(routeMatches, equals(1), reason: 'GoRoute should not be duplicated');

    // Check app_routes.dart content
    final appRoutes = File('$outputDir/routing/app_routes.dart');
    expect(appRoutes.existsSync(), isTrue);
    final appContent = appRoutes.readAsStringSync();

    // It should point to ListingRoutes.getListingByBarcode
    expect(
      appContent.contains(
        'static const String getListingByBarcode = ListingRoutes.getListingByBarcode;',
      ),
      isTrue,
    );
  });

  test('regenerates routes index with correct getter names', () async {
    final builder = RouteBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    // 1. Generate listing routes
    await builder.generate(
      GeneratorConfig(
        name: 'GetListingByBarcode',
        domain: 'listing',
        paramsType: 'String',
        returnsType: 'Listing?',
        generateRoute: true,
        outputDir: outputDir,
      ),
    );

    // 2. Generate product routes (entity-based)
    await builder.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const ['get', 'getList'],
        generateRoute: true,
        outputDir: outputDir,
      ),
    );

    final indexPath = File('$outputDir/routing/index.dart');
    expect(indexPath.existsSync(), isTrue);
    final content = indexPath.readAsStringSync();

    // Check exports
    expect(content.contains("export 'listing_routes.dart';"), isTrue);
    expect(content.contains("export 'product_routes.dart';"), isTrue);

    // Check getAllRoutes contains the spread calls to correctly named getters
    // listingRoutes() and productRoutes()
    expect(content.contains("...listingRoutes()"), isTrue);
    expect(content.contains("...productRoutes()"), isTrue);

    // Verify it doesn't contain getListingRoutes() or getProductRoutes()
    expect(content.contains("getListingRoutes()"), isFalse);
    expect(content.contains("getProductRoutes()"), isFalse);
  });

  test('generates extension methods with leading slash', () async {
    final builder = RouteBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    await builder.generate(
      GeneratorConfig(
        name: 'User',
        methods: const ['get', 'getList', 'update'],
        generateRoute: true,
        outputDir: outputDir,
      ),
    );

    final appRoutes = File('$outputDir/routing/app_routes.dart');
    expect(appRoutes.existsSync(), isTrue);
    final content = appRoutes.readAsStringSync();

    expect(
      content.contains("void goToUserDetail(String id) => go('/user/\$id');"),
      isTrue,
    );
    expect(
      content.contains(
        "void goToUserUpdate(String id) => go('/user/\$id/edit');",
      ),
      isTrue,
    );
  });
}
