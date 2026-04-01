import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    expect(content.contains('StreamUseCase<User, UserParams>'), isTrue);
    expect(content.contains('Stream<User> execute'), isTrue);
    expect(content.contains('UserParams'), isTrue);
    expect(content.contains('CancelToken?'), isTrue);
    expect(content.contains('final UserService _userService;'), isTrue);
    expect(content.contains('StreamUserUseCase(this._userService);'), isTrue);
    expect(content.contains('return _userService.streamUser(params);'), isTrue);
  });

  test('generates custom future usecase with service dependency', () async {
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
