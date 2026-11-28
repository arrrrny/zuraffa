import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/builder/patterns/common_patterns.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_usecase_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates entity usecase with code_builder', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'Todo',
      methods: ['get'],
      repo: 'Todo',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    expect(files.length, equals(1));
    final content = files.first.content ?? '';
    expect(content.contains('class GetTodoUseCase'), isTrue);
    expect(content.contains('UseCase<Todo, QueryParams<Todo>>'), isTrue);
    expect(content.contains('Future<Todo> execute'), isTrue);
    expect(content.contains('QueryParams<Todo>'), isTrue);
    expect(content.contains('CancelToken?'), isTrue);
  });

  test(
    'parses formatted WatchUseCase output for DI and test consumers',
    () async {
      final file = File(
        '$outputDir/domain/usecases/product/watch_product_usecase.dart',
      );
      await file.create(recursive: true);
      await file.writeAsString('''
class WatchProductUseCase extends WatchUseCase<
  WatchUseCaseIntent<QueryParams<Product>>,
  Product
> {}
''');

      final info = await CommonPatterns.parseUseCaseInfo(
        'WatchProduct',
        GeneratorConfig(
          name: 'Product',
          domain: 'product',
          outputDir: outputDir,
        ),
        outputDir,
      );

      expect(info.useCaseType, 'stream');
      expect(info.paramsType, 'QueryParams<Product>');
      expect(info.returnsType, 'Product');
    },
  );

  test('generates custom sync usecase with repo dependency', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'SyncUser',
      repo: 'User',
      domain: 'user',
      paramsType: 'UserParams',
      returnsType: 'User',
      useCaseType: 'sync',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(content.contains('class SyncUserUseCase'), isTrue);
    expect(content.contains('SyncUseCase<User, UserParams>'), isTrue);
    expect(content.contains('User execute'), isTrue);
    expect(content.contains('UserParams'), isTrue);
  });

  test('generates custom stream usecase with service dependency', () async {
    final serviceDir = Directory('$outputDir/domain/services');
    await serviceDir.create(recursive: true);
    await File('${serviceDir.path}/user_service.dart').writeAsString(
      'abstract class UserService {\n  Stream<User> streamUser(UserParams params);\n}',
    );
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'StreamUser',
      service: 'User',
      domain: 'user',
      paramsType: 'UserParams',
      returnsType: 'User',
      useCaseType: 'stream',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(content.contains('class StreamUserUseCase'), isTrue);
    expect(
      content.contains('WatchUseCase<WatchUseCaseIntent<UserParams>, User>'),
      isTrue,
    );
    expect(content.contains('Result<User, AppFailure> read('), isTrue);
    expect(
      content.contains('Future<Result<User, AppFailure>> execute('),
      isTrue,
    );
    expect(content.contains('WatchUseCaseIntent<UserParams> intent'), isTrue);
    expect(content.contains('ZfaContext ctx'), isTrue);
    expect(content.contains('CancelToken?'), isFalse);
    expect(content.contains('final UserService _userService;'), isTrue);
    expect(content.contains('StreamUserUseCase(this._userService);'), isTrue);
    expect(
      content.contains(
        'return Result.success(await _userService.streamUser(intent.params).first);',
      ),
      isTrue,
    );
  });

  test('generates custom background usecase with async UseCase base', () async {
    final serviceDir = Directory('$outputDir/domain/services');
    await serviceDir.create(recursive: true);
    await File('${serviceDir.path}/user_service.dart').writeAsString(
      'abstract class UserService {\n  Future<User> backgroundUser(UserParams params);\n}',
    );
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'BackgroundUser',
      service: 'User',
      domain: 'user',
      paramsType: 'UserParams',
      returnsType: 'User',
      useCaseType: 'background',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(content.contains('class BackgroundUserUseCase'), isTrue);
    expect(content.contains('UseCase<User, UserParams>'), isTrue);
    expect(content.contains('Future<User> execute'), isTrue);
    expect(content.contains('CancelToken?'), isTrue);
    expect(content.contains('BackgroundUseCase'), isFalse);
    expect(content.contains('BackgroundTask'), isFalse);
    expect(
      content.contains('return await _userService.backgroundUser(params);'),
      isTrue,
    );
  });

  test('appends background execute without retired task APIs', () async {
    final serviceDir = Directory('$outputDir/domain/services');
    await serviceDir.create(recursive: true);
    await File('${serviceDir.path}/user_service.dart').writeAsString(
      'abstract class UserService {\n  Future<User> backgroundUser(UserParams params);\n}',
    );
    final file = File(
      '$outputDir/domain/usecases/user/background_user_usecase.dart',
    );
    await file.create(recursive: true);
    await file.writeAsString('''
import 'package:zuraffa/zuraffa.dart';
import '../../services/user_service.dart';

class BackgroundUserUseCase extends UseCase<User, UserParams> {
  BackgroundUserUseCase(this._userService);
  final UserService _userService;
}
''');

    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: false),
    );
    final config = GeneratorConfig(
      name: 'BackgroundUser',
      service: 'User',
      domain: 'user',
      paramsType: 'UserParams',
      returnsType: 'User',
      useCaseType: 'background',
      appendToExisting: true,
      force: false,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = await file.readAsString();
    expect(files.single.action, 'overwritten');
    expect(content, contains('Future<User> execute('));
    expect(
      content,
      contains('return await _userService.backgroundUser(params);'),
    );
    expect(content, isNot(contains('BackgroundTask')));
    expect(content, isNot(contains('BackgroundUseCase')));
  });

  test('generates custom future usecase with service dependency', () async {
    final serviceDir = Directory('$outputDir/domain/services');
    await serviceDir.create(recursive: true);
    await File('${serviceDir.path}/listing_service.dart').writeAsString(
      'abstract class ListingService {\n  Future<Listing?> getListingByBarcode(String params);\n}',
    );
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'GetListingByBarcode',
      service: 'Listing',
      domain: 'listing',
      paramsType: 'String',
      returnsType: 'Listing?',
      useCaseType: 'future',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';

    expect(content.contains('class GetListingByBarcodeUseCase'), isTrue);
    expect(content.contains('UseCase<Listing?, String>'), isTrue);
    expect(content.contains('final ListingService _listingService;'), isTrue);
    expect(
      content.contains('GetListingByBarcodeUseCase(this._listingService);'),
      isTrue,
    );
    expect(
      content.contains(
        'return await _listingService.getListingByBarcode(params);',
      ),
      isTrue,
    );
  });

  test(
    'generates non-entity completable usecase with service, no explicit domain (#2140)',
    () async {
      final serviceDir = Directory('$outputDir/domain/services');
      await serviceDir.create(recursive: true);
      await File(
        '${serviceDir.path}/schedule_price_check_service.dart',
      ).writeAsString(
        'abstract class SchedulePriceCheckService {\n  Future<void> schedulePriceCheck(NoParams params);\n}',
      );
      final plugin = UseCasePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      // The issue's exact shape: a non-entity completable usecase that binds
      // to an existing service interface, with NO --domain passed. The guard
      // must not demand --domain when the service name scopes the work —
      // the domain falls back to the config name (effectiveDomain), the same
      // convention zfa provider create documents.
      final config = GeneratorConfig(
        name: 'SchedulePriceCheck',
        service: 'SchedulePriceCheckService',
        paramsType: 'NoParams',
        returnsType: 'void',
        useCaseType: 'completable',
        noEntity: true,
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      expect(files.length, equals(1));
      final content = files.first.content ?? '';
      expect(content.contains('class SchedulePriceCheckUseCase'), isTrue);
      expect(content.contains('CompletableUseCase<NoParams>'), isTrue);
      expect(
        content.contains(
          'final SchedulePriceCheckService _schedulePriceCheckService;',
        ),
        isTrue,
      );
      // The file lands beside the service, under the name-derived domain.
      expect(
        files.first.path.contains('/domain/usecases/schedule_price_check/'),
        isTrue,
        reason:
            'domain must fall back to the config name (effectiveDomain) '
            'when --domain is omitted and a service is present (#2140)',
      );
    },
  );

  test(
    'non-entity completable usecase with useService binds the feature service '
    '(direct --use-service --no-entity path, #2145 review follow-up)',
    () async {
      // Review follow-up on #2145 (zuraffa-review[bot], minor): the
      // make-level `--use-service --no-entity` bridge had #2140 coverage
      // in make_command_test, but the DIRECT plugin path — useService
      // true with no explicit service name, so effectiveService resolves
      // to <Name>Service — had none. Mirror the make-level case here so
      // a regression in the plugin's no-entity useService read is caught
      // at the plugin level too.
      final serviceDir = Directory('$outputDir/domain/services');
      await serviceDir.create(recursive: true);
      await File('${serviceDir.path}/sync_catalog_service.dart').writeAsString(
        'abstract class SyncCatalogService {\n  Future<void> syncCatalog(NoParams params);\n}',
      );
      final plugin = UseCasePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'SyncCatalog',
        paramsType: 'NoParams',
        returnsType: 'void',
        useCaseType: 'completable',
        noEntity: true,
        useService: true,
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      expect(files.length, equals(1));
      final content = files.first.content ?? '';
      expect(content.contains('class SyncCatalogUseCase'), isTrue);
      expect(
        content.contains('final SyncCatalogService _syncCatalogService;'),
        isTrue,
        reason:
            'useService on a direct no-entity run must resolve <Name>Service '
            'and bind it, matching --use-service\'s meaning (#2145 review)',
      );
    },
  );

  test(
    'non-entity completable usecase without service or domain still fails loudly (#2140)',
    () async {
      final plugin = UseCasePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'OrphanAction',
        paramsType: 'NoParams',
        returnsType: 'void',
        useCaseType: 'completable',
        noEntity: true,
        outputDir: outputDir,
      );
      // The intent is "fail loudly, never emit a use case that cannot
      // compile" (#2140). Since #2141 merged, the non-entity completable
      // path infers `<Name>Service` and resolves it against the on-disk
      // interface (#1799) before the domain guard runs, so the loud
      // failure now names the missing service rather than the missing
      // domain — the same ArgumentError contract, a more actionable
      // message. This mirrors master's own #2141 regression assertion in
      // test/regression/issue_2141_completable_infer_service_test.dart.
      await expectLater(
        plugin.generate(config),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('service interface not found'),
              contains('OrphanActionService'),
            ),
          ),
        ),
      );
    },
  );

  test('generates orchestrator usecase', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'OrchestrateOrders',
      usecases: ['GetOrder', 'SaveOrder'],
      paramsType: 'OrderParams',
      returnsType: 'Order',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(content.contains('class OrchestrateOrdersUseCase'), isTrue);
    expect(content.contains('UseCase<Order, OrderParams>'), isTrue);
  });

  test('generates stream orchestrator with watch intent contract', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'OrchestrateOrders',
      usecases: ['GetOrder', 'SaveOrder'],
      paramsType: 'OrderParams',
      returnsType: 'Order',
      useCaseType: 'stream',
      domain: 'order',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(
      content.contains('WatchUseCase<WatchUseCaseIntent<OrderParams>, Order>'),
      isTrue,
    );
    expect(content.contains('Result<Order, AppFailure> read('), isTrue);
    expect(
      content.contains('Future<Result<Order, AppFailure>> execute('),
      isTrue,
    );
  });

  test(
    'generates stream polymorphic usecases with watch intent contract',
    () async {
      final plugin = UseCasePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'FetchOrder',
        variants: ['Cached', 'Remote'],
        paramsType: 'OrderParams',
        returnsType: 'Order',
        useCaseType: 'stream',
        domain: 'order',
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      final watchSources = files
          .map((file) => File(file.path).readAsStringSync())
          .where((content) => content.contains('WatchUseCase<'))
          .toList();
      expect(watchSources, hasLength(1));
      expect(
        watchSources.single.contains(
          'WatchUseCase<WatchUseCaseIntent<OrderParams>, Order>',
        ),
        isTrue,
      );
      final variantSources = files
          .map((file) => File(file.path).readAsStringSync())
          .where(
            (content) => content.contains('Result<Order, AppFailure> read('),
          )
          .toList();
      expect(variantSources, hasLength(2));
      for (final content in variantSources) {
        expect(content, contains('extends FetchOrderUseCase'));
        expect(
          content.contains('Future<Result<Order, AppFailure>> execute('),
          isTrue,
        );
      }
    },
  );

  test('generates polymorphic usecases and factory', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'FetchUser',
      repo: 'User',
      variants: ['Cached', 'Remote'],
      paramsType: 'UserParams',
      returnsType: 'User',
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    expect(files.length, equals(4));
    expect(
      files.any((f) => f.path.endsWith('fetch_user_usecase.dart')),
      isTrue,
    );
    expect(
      files.any((f) => f.path.endsWith('fetch_user_usecase_factory.dart')),
      isTrue,
    );
  });

  test('smart append adds execute method to existing class', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final filePath = '$outputDir/domain/usecases/auth/login_usecase.dart';
    await File(filePath).create(recursive: true);
    await File(filePath).writeAsString(
      'import \'package:zuraffa/zuraffa.dart\';\n\nclass LoginUseCase extends UseCase<void, NoParams> {\n  LoginUseCase();\n}\n',
    );

    final config = GeneratorConfig(
      name: 'Login',
      domain: 'auth',
      paramsType: 'NoParams',
      returnsType: 'void',
      useCaseType: 'sync',
      appendToExisting: true,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(content.contains('execute(NoParams params'), isTrue);
  });
  test('generates custom usecase with multiple parameters', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final paramsStr =
        '[ParserConfig parserConfig, "Map<String, String>" placeholders]';
    final multipleParams = GeneratorConfig.parseParams(paramsStr);

    final serviceDir = Directory('$outputDir/domain/services');
    await serviceDir.create(recursive: true);
    await File('${serviceDir.path}/zik_service.dart').writeAsString(
      'abstract class ZikService {\n  Future<ParserConfig> replaceRefererPlaceholders(ParserConfig parserConfig, Map<String, String> placeholders);\n}',
    );

    final config = GeneratorConfig(
      name: 'ReplaceRefererPlaceholders',
      service: 'Zik',
      domain: 'parser',
      multipleParams: multipleParams,
      returnsType: 'ParserConfig',
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);
    final content = files.first.content ?? '';

    expect(content.contains('class ReplaceRefererPlaceholdersUseCase'), isTrue);
    expect(
      content.contains(
        'UseCase<ParserConfig, ReplaceRefererPlaceholdersParams>',
      ),
      isTrue,
    );
    expect(content.contains('Future<ParserConfig> execute'), isTrue);
    expect(content.contains('ReplaceRefererPlaceholdersParams params'), isTrue);

    // Check params class generation
    expect(content.contains('class ReplaceRefererPlaceholdersParams'), isTrue);
    expect(content.contains('final ParserConfig parserConfig;'), isTrue);
    expect(content.contains('final Map<String, String> placeholders;'), isTrue);
    expect(
      content.contains('const ReplaceRefererPlaceholdersParams({'),
      isTrue,
    );

    // Check service call with unpacked params
    final normalizedContent = content.replaceAll(RegExp(r'\s+'), ' ');
    expect(
      normalizedContent.contains(
        'return await _zikService.replaceRefererPlaceholders( params.parserConfig, params.placeholders, );',
      ),
      isTrue,
    );
  });
}
