import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/provider/provider_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_provider_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates provider and appends to existing', () async {
    final plugin = ProviderPlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    // 1. Generate first provider
    final config1 = GeneratorConfig(
      name: 'GetListingByBarcode',
      service: 'Listing',
      domain: 'listing',
      paramsType: 'String',
      returnsType: 'Listing?',
      outputDir: outputDir,
      generateData: true,
    );
    
    final files1 = await plugin.generate(config1);
    expect(files1.length, equals(1));
    final providerFile = File(files1.first.path);
    expect(providerFile.existsSync(), isTrue);
    
    final content1 = providerFile.readAsStringSync();
    expect(content1.contains('class ListingProvider'), isTrue);
    expect(content1.contains('Future<Listing?> getListingByBarcode(String params)'), isTrue);
    expect(content1.contains("import '../../../domain/entities/listing/listing.dart';"), isTrue);
    expect(content1.contains('listing_?'), isFalse);

    // 2. Generate second provider method in same domain with append
    final config2 = GeneratorConfig(
      name: 'SearchListings',
      service: 'Listing',
      domain: 'listing',
      paramsType: 'String',
      returnsType: 'List<Listing>',
      outputDir: outputDir,
      generateData: true,
      appendToExisting: true,
    );

    final files2 = await plugin.generate(config2);
    expect(files2.length, equals(1));
    
    final content2 = providerFile.readAsStringSync();
    // Should have both methods
    expect(content2.contains('Future<Listing?> getListingByBarcode(String params)'), isTrue);
    expect(content2.contains('Future<List<Listing>> searchListings(String params)'), isTrue);
    
    // Should not have duplicated class header
    final classMatches = 'class ListingProvider'.allMatches(content2).length;
    expect(classMatches, equals(1));
  });
}
