import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
      dryRun: false,
      force: true,
      verbose: false,
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
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'SyncUser',
      repo: 'User',
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
      dryRun: false,
      force: true,
      verbose: false,
    );
    final config = GeneratorConfig(
      name: 'StreamUser',
      service: 'User',
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
  });

  test('generates orchestrator usecase', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
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
      dryRun: false,
      force: true,
      verbose: false,
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
      dryRun: false,
      force: false,
      verbose: false,
    );
    final filePath = '${outputDir}/domain/usecases/auth/login_usecase.dart';
    await File(filePath).create(recursive: true);
    await File(filePath).writeAsString(
      'import \'package:zuraffa/zuraffa.dart\';\n\nclass LoginUseCase extends UseCase<void, NoParams> {\n  LoginUseCase();\n}\n',
    );

    final config = GeneratorConfig(
      name: 'Login',
      paramsType: 'NoParams',
      returnsType: 'void',
      appendToExisting: true,
      outputDir: outputDir,
    );
    final files = await plugin.generate(config);
    final content = files.first.content ?? '';
    expect(content.contains('execute(NoParams params'), isTrue);
  });
}
