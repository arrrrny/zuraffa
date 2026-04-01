import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('cache_compilation_test');
    await writePubspec(workspace);
    // Create entity file because it's required for repository generation
    final entityDir = Directory('${workspace.outputDir}/domain/entities/order');
    entityDir.createSync(recursive: true);
    File('${entityDir.path}/order.dart').writeAsStringSync('''
class Order {
  final String id;
  Order({required this.id});
}
''');

    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test('generated cached repository should compile', () async {
    final config = GeneratorConfig(
      name: 'Order',
      methods: const ['get', 'getList'],
      generateData: true,
      enableCache: true,
      cacheStorage: 'hive',
      outputDir: outputDir,
    );
    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: true,
      ),
    );

    final result = await generator.generate();
    expect(result.success, isTrue);

    final repoFile = File(
      '$outputDir/data/repositories/data_order_repository.dart',
    );
    expect(repoFile.existsSync(), isTrue);
    final content = repoFile.readAsStringSync();
    print('Generated Repository Content:\n\$content');

    // Check for obvious errors in generated content
    expect(content, contains('final OrderLocalDataSource _localDataSource;'));
    expect(content, contains('final OrderDataSource _remoteDataSource;'));
    expect(
      content,
      contains('final CachePolicy _cachePolicy;'),
      reason: 'CachePolicy field missing',
    );

    // Check constructor
    expect(content, contains('this._cachePolicy,'));

    // Check imports
    expect(content, contains("import 'package:zuraffa/zuraffa.dart';"));
  });

  test('generated cached DI should compile', () async {
    final config = GeneratorConfig(
      name: 'Order',
      methods: const ['get', 'getList'],
      generateData: true,
      enableCache: true,
      cacheStorage: 'hive',
      generateDi: true,
      outputDir: outputDir,
    );
    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: true,
      ),
    );

    final result = await generator.generate();
    expect(result.success, isTrue);

    final diRepoFile = File(
      '$outputDir/di/repositories/order_repository_di.dart',
    );
    expect(diRepoFile.existsSync(), isTrue);
    final content = diRepoFile.readAsStringSync();
    print('Generated DI Repository Content:\n$content');

    expect(content, contains('registerOrderRepository'));
    expect(content, contains('OrderRemoteDataSource'));
    expect(content, contains('OrderLocalDataSource'));
    expect(content, contains('createDailyCachePolicy()'));
    expect(content, contains("import '../../cache/daily_cache_policy.dart';"));
  });
}
