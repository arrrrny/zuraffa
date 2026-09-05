import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/conformance/repository_conformance_checker.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_conf_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  RepositoryPlugin plugin({bool force = true}) => RepositoryPlugin(
    outputDir: outputDir,
    options: GeneratorOptions(dryRun: false, force: force, verbose: false),
  );

  group('RepositoryConformanceChecker (unit)', () {
    const interfaceSource = '''
import 'package:zuraffa/zuraffa.dart';

abstract class ProductRepository {
  Future<Product> get(QueryParams<Product> params);
  Future<Product> update(UpdateParams<String, ProductPatch> params);
}
''';

    const conformingImplSource = '''
import 'product_repository.dart';

class DataProductRepository implements ProductRepository {
  @override
  Future<Product> get(QueryParams<Product> params) async => throw '';

  @override
  Future<Product> update(UpdateParams<String, ProductPatch> params) async =>
      throw '';
}
''';

    test('accepts a conforming interface/impl pair', () {
      final result = const RepositoryConformanceChecker().check(
        interfaceSource: interfaceSource,
        implementationSource: conformingImplSource,
        interfaceClassName: 'ProductRepository',
        implementationClassName: 'DataProductRepository',
      );
      expect(result.ok, isTrue, reason: '${result.failures}');
    });

    test('rejects an interface method with no implementation', () {
      final result = const RepositoryConformanceChecker().check(
        interfaceSource: interfaceSource,
        implementationSource: '''
class DataProductRepository implements ProductRepository {
  @override
  Future<Product> get(QueryParams<Product> params) async => throw '';
}
''',
        interfaceClassName: 'ProductRepository',
        implementationClassName: 'DataProductRepository',
      );
      expect(result.ok, isFalse);
      expect(result.failures, hasLength(1));
      expect(result.failures.single.method, 'update');
      expect(result.failures.single.side, 'implementation');
    });

    test('rejects an impl method whose @override has no interface member', () {
      final result = const RepositoryConformanceChecker().check(
        interfaceSource: interfaceSource,
        implementationSource: '''
class DataProductRepository implements ProductRepository {
  @override
  Future<Product> get(QueryParams<Product> params) async => throw '';

  @override
  Future<Product> update(UpdateParams<String, ProductPatch> params) async =>
      throw '';

  @override
  Future<void> purgeAll() async {}
}
''',
        interfaceClassName: 'ProductRepository',
        implementationClassName: 'DataProductRepository',
      );
      expect(result.ok, isFalse);
      final purge = result.failures.single;
      expect(purge.method, 'purgeAll');
      expect(purge.side, 'interface');
    });

    test('rejects an implementation missing @override', () {
      final result = const RepositoryConformanceChecker().check(
        interfaceSource: interfaceSource,
        implementationSource: '''
class DataProductRepository implements ProductRepository {
  @override
  Future<Product> get(QueryParams<Product> params) async => throw '';

  Future<Product> update(UpdateParams<String, ProductPatch> params) async =>
      throw '';
}
''',
        interfaceClassName: 'ProductRepository',
        implementationClassName: 'DataProductRepository',
      );
      expect(result.ok, isFalse);
      expect(result.failures.single.method, 'update');
      expect(result.failures.single.message, contains('@override'));
    });

    test('delta scope only audits the methods contributed by this run', () {
      // Pre-existing interface member `custom()` has no impl — but it was
      // NOT contributed by this run, so the delta-scope check passes.
      final result = const RepositoryConformanceChecker().check(
        interfaceSource: '''
abstract class UserRepository {
  Future<void> custom();
  Future<User> get(QueryParams<User> params);
}
''',
        implementationSource: '''
class DataUserRepository implements UserRepository {
  Future<void> custom() async {}
  @override
  Future<User> get(QueryParams<User> params) async => throw '';
}
''',
        interfaceClassName: 'UserRepository',
        implementationClassName: 'DataUserRepository',
        requiredInterfaceMethods: {'get'},
      );
      expect(result.ok, isTrue, reason: '${result.failures}');
    });
  });

  group('generation-time gate (plugin)', () {
    test('a fresh conforming pair generates without failing', () async {
      final config = GeneratorConfig(
        name: 'Product',
        methods: ['get', 'update'],
        generateData: true,
        outputDir: outputDir,
        force: true,
      );
      final files = await plugin().generate(config);
      expect(files, hasLength(2));
    });

    test(
      'a deliberate mismatch fails at generation time with --> fix:',
      () async {
        // The unknown verb `purgeAll` never reaches the interface switch (no
        // declaration) but the implementation's default branch still emits it
        // with @override — a deliberate interface/impl mismatch that must now
        // fail the generation instead of shipping a pair that cannot compile.
        final config = GeneratorConfig(
          name: 'Product',
          methods: ['get', 'purgeAll'],
          generateData: true,
          outputDir: outputDir,
          force: true,
        );

        await expectLater(
          plugin().generate(config),
          throwsA(
            isA<RepositoryConformanceException>().having(
              (e) => e.toString(),
              'message',
              allOf(contains('--> fix:'), contains('purgeAll')),
            ),
          ),
        );
      },
    );

    test('a synced pair conforms (sync ops carry @override)', () async {
      final config = GeneratorConfig(
        name: 'Product',
        methods: ['get', 'update'],
        generateData: true,
        enableSync: true,
        outputDir: outputDir,
        force: true,
      );

      final files = await plugin().generate(config);
      final impl = files.firstWhere(
        (f) => f.path.contains('data_product_repository.dart'),
      );
      expect(
        impl.content,
        allOf(
          contains('syncPending'),
          contains('pullRemote'),
          isNot(contains('override_on_non_overriding_member')),
        ),
      );
    });
  });
}
