import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_service_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates service interface for custom usecase', () async {
    final plugin = ServicePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: false,
        verbose: false,
      ),
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'SendEmail',
        methods: const [],
        service: 'Email',
        domain: 'email',
        paramsType: 'EmailParams',
        returnsType: 'SendResult',
        outputDir: outputDir,
      ),
    );

    final serviceFile = File('$outputDir/domain/services/email_service.dart');

    expect(serviceFile.existsSync(), isTrue);
    final content = serviceFile.readAsStringSync();
    expect(content.contains('abstract class EmailService'), isTrue);
    expect(content.contains('/// Service interface for EmailService'), isTrue);
    expect(
      content.contains('Future<SendResult> sendEmail(EmailParams params);'),
      isTrue,
    );
    expect(content.contains('throw UnimplementedError();'), isFalse);
  });

  test('uses stream return type for stream usecases', () async {
    final plugin = ServicePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: false,
        verbose: false,
      ),
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'WatchOrders',
        methods: const [],
        service: 'Orders',
        domain: 'orders',
        paramsType: 'OrderFilter',
        returnsType: 'Order',
        useCaseType: 'stream',
        outputDir: outputDir,
      ),
    );

    final serviceFile = File('$outputDir/domain/services/orders_service.dart');

    final content = serviceFile.readAsStringSync();
    expect(
      content.contains('Stream<Order> watchOrders(OrderFilter params)'),
      isTrue,
    );
  });

  test('includes NoParams in service interface if specified', () async {
    final plugin = ServicePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: false,
        verbose: false,
      ),
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'ScanBarcode',
        methods: const [],
        service: 'Barcode',
        domain: 'barcode',
        paramsType: 'NoParams',
        returnsType: 'Barcode',
        outputDir: outputDir,
      ),
    );

    final serviceFile = File('$outputDir/domain/services/barcode_service.dart');
    final content = serviceFile.readAsStringSync();

    expect(
      content.contains('Future<Barcode> scanBarcode(NoParams params);'),
      isTrue,
    );
  });

  test(
    'correctly generates relative entity imports in service interface',
    () async {
      final plugin = ServicePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: false,
          verbose: false,
        ),
      );

      await plugin.generate(
        GeneratorConfig(
          name: 'GetListingByBarcode',
          service: 'Listing',
          domain: 'listing',
          paramsType: 'Barcode',
          returnsType: 'Listing?',
          outputDir: outputDir,
        ),
      );

      final serviceFile = File(
        '$outputDir/domain/services/listing_service.dart',
      );
      final content = serviceFile.readAsStringSync();

      expect(content.contains("domain/entities/barcode/barcode.dart"), isTrue);
      expect(content.contains("domain/entities/listing/listing.dart"), isTrue);
    },
  );

  test(
    'correctly generates complex entity imports in service interface',
    () async {
      final plugin = ServicePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: false,
          verbose: false,
        ),
      );

      await plugin.generate(
        GeneratorConfig(
          name: 'GetListingByBarcode',
          service: 'Listing',
          domain: 'listing',
          paramsType: 'Barcode',
          returnsType: 'BarcodeListing?',
          useCaseType: 'stream',
          outputDir: outputDir,
        ),
      );

      final serviceFile = File(
        '$outputDir/domain/services/listing_service.dart',
      );
      final content = serviceFile.readAsStringSync();

      expect(content.contains("domain/entities/barcode/barcode.dart"), isTrue);
      expect(
        content.contains(
          "domain/entities/barcode_listing/barcode_listing.dart",
        ),
        isTrue,
      );
    },
  );

  test('correctly generates relative entity imports in usecase', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: false,
        verbose: false,
      ),
    );

    await plugin.generate(
      GeneratorConfig(
        name: 'GetListingByBarcode',
        service: 'Listing',
        domain: 'listing',
        paramsType: 'Barcode',
        returnsType: 'BarcodeListing?',
        useCaseType: 'stream',
        outputDir: outputDir,
      ),
    );

    final usecaseFile = File(
      '$outputDir/domain/usecases/listing/get_listing_by_barcode_usecase.dart',
    );
    final content = usecaseFile.readAsStringSync();
    print('--- USECASE CONTENT ---\n$content\n----------------------');

    expect(content.contains("domain/entities/barcode/barcode.dart"), isTrue);
    expect(
      content.contains("domain/entities/barcode_listing/barcode_listing.dart"),
      isTrue,
    );
  });
}
