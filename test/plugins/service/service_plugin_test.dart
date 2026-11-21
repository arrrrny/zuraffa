import 'dart:io';

import 'package:test/test.dart';
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

      // Issue #1030: custom services write flat to domain/services/, so
      // entity imports must resolve WITHOUT the extra `domain` segment.
      // The old assertion (`contains('domain/entities/...')`) matched the
      // broken `../domain/entities/...` import — a substring lie that
      // never compiled.
      expect(content.contains("'../entities/barcode/barcode.dart'"), isTrue);
      expect(content.contains("'../entities/listing/listing.dart'"), isTrue);
      expect(
        content.contains("'../domain/entities/"),
        isFalse,
        reason:
            'the flat services layout must not carry a domain segment '
            'in entity imports',
      );
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

      expect(content.contains("'../entities/barcode/barcode.dart'"), isTrue);
      expect(
        content.contains("'../entities/barcode_listing/barcode_listing.dart'"),
        isTrue,
      );
      expect(content.contains("'../domain/entities/"), isFalse);
    },
  );

  test('correctly generates relative entity imports in usecase', () async {
    // The usecase generator resolves its service method from the service
    // interface (#1799), so the interface must exist first.
    final servicePlugin = ServicePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: false,
        verbose: false,
      ),
    );
    await servicePlugin.generate(
      GeneratorConfig(
        name: 'GetListingByBarcode',
        service: 'Listing',
        domain: 'listing',
        paramsType: 'Barcode',
        returnsType: 'BarcodeListing?',
        outputDir: outputDir,
      ),
    );

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

  test(
    'issue #2131 — no-entity service must not import phantom entities',
    () async {
      // Issue #2131: a no-entity standalone service (custom --params/
      // --returns, no backing entity) must not emit the missing-file
      // fallback import — it would reference a domain/entities/<type>/
      // <type>.dart that does not exist and fail `zfa build`'s analyzer
      // gate with `uri_does_not_exist` / `undefined_class`. The stream
      // usecase generator already guards its entity imports with
      // `includeMissingEntityFallback: !config.noEntity` (2025 review,
      // issue #2023); the service builder did not, so it kept emitting
      // the phantom imports.
      final plugin = ServicePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      await plugin.generate(
        GeneratorConfig(
          name: 'RunPriceCheckForItem',
          service: 'RunPriceCheckForItemService',
          domain: 'price_check',
          methods: const [],
          paramsType: 'PriceCheckParams',
          returnsType: 'PriceCheckItemResult',
          useCaseType: 'stream',
          noEntity: true,
          outputDir: outputDir,
        ),
      );

      final serviceFile = File(
        '$outputDir/domain/services/run_price_check_for_item_service.dart',
      );
      final content = serviceFile.readAsStringSync();

      // The service must NOT import the nonexistent entity files.
      expect(
        content,
        isNot(contains('entities/price_check_params')),
        reason: 'no phantom entity import for the custom params type',
      );
      expect(
        content,
        isNot(contains('entities/price_check_item_result')),
        reason: 'no phantom entity import for the custom returns type',
      );
    },
  );

  test(
    'issue #2131 — entity-backed service still imports the entity file',
    () async {
      // The #2131 guard must not over-skip: an entity-backed service
      // (noEntity: false) with a custom params type MUST keep importing
      // its entity file.
      final plugin = ServicePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
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

      expect(
        content.contains("'../entities/barcode/barcode.dart'"),
        isTrue,
        reason: 'an entity-backed service still imports its entity file',
      );
    },
  );
}
