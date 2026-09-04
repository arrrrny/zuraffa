import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/plugins/repository/contract/repository_contract_manifest.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';
import 'package:zuraffa/src/utils/source_interface_guard.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_manifest_');
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

  Future<List<GeneratedFile>> generatePair() async {
    final config = GeneratorConfig(
      name: 'Product',
      methods: ['get', 'update'],
      generateData: true,
      outputDir: outputDir,
      force: true,
    );
    return plugin().generate(config);
  }

  RepositoryContractManifestStore storeFor(Directory root) =>
      RepositoryContractManifestStore(projectRoot: root.path);

  group('contract extractor + hash (unit)', () {
    test('extracts method set with params/returns signatures', () {
      final methods = const RepositoryContractExtractor().extract(
        interfaceSource: '''
abstract class ProductRepository {
  Future<Product> get(QueryParams<Product> params);
  Stream<bool> get isInitialized;
  Future<void> syncPending({CancelToken? cancelToken});
}
''',
        className: 'ProductRepository',
      );

      expect(methods, hasLength(3));
      expect(methods[0].name, 'get');
      expect(methods[0].returns, 'Future<Product>');
      expect(methods[0].params, ['QueryParams<Product> params']);
      expect(methods[1].name, 'isInitialized');
      expect(methods[1].returns, 'Stream<bool>');
      expect(methods[1].params, isEmpty);
      expect(methods[2].name, 'syncPending');
      expect(methods[2].params, ['CancelToken? cancelToken']);
    });

    test('methods hash is stable across runs and sensitive to content', () {
      String hash(List<RepositoryContractMethod> methods) =>
          RepositoryContractManifest.hashOfMethods(methods);

      final a = const RepositoryContractMethod(
        name: 'get',
        returns: 'Future<Product>',
        params: ['QueryParams<Product> params'],
      );
      final b = const RepositoryContractMethod(
        name: 'update',
        returns: 'Future<Product>',
        params: ['UpdateParams<String, ProductPatch> params'],
      );

      expect(hash([a, b]), hash([a, b]), reason: 'same input, same hash');
      expect(
        hash([a, b]),
        isNot(hash([b, a])),
        reason: 'declaration order is part of the contract',
      );
      expect(
        hash([a]),
        isNot(hash([a, b])),
        reason: 'method set changes must change the hash',
      );
    });
  });

  group('generation writes the contract manifest', () {
    test(
      'fresh generation writes repository-<entity>.json in the receipts dir',
      () async {
        await generatePair();

        final manifest = await storeFor(tempDir).loadForEntity('Product');
        expect(manifest, isNotNull);
        expect(manifest!.schema, 'repository-contract.v1');
        expect(manifest.entity, 'Product');
        expect(manifest.interface.className, 'ProductRepository');
        expect(
          manifest.interface.path,
          'lib/src/domain/repositories/product_repository.dart',
        );
        expect(manifest.implementation.className, 'DataProductRepository');
        expect(
          manifest.implementation.path,
          'lib/src/data/repositories/data_product_repository.dart',
        );
        expect(manifest.methodNames, containsAll(['get', 'update']));
        expect(
          manifest.methodsSha256,
          RepositoryContractManifest.hashOfMethods(manifest.methods),
        );
        expect(
          File('${tempDir.path}/${manifest.interface.path}').existsSync(),
          isTrue,
        );
      },
    );

    test('manifest hash is stable across independent generations', () async {
      final outer = await Directory.systemTemp.createTemp(
        'zuraffa_manifest_b_',
      );
      addTearDown(() => outer.delete(recursive: true));
      final secondDir = Directory('${outer.path}/lib/src')
        ..createSync(recursive: true);

      await generatePair();
      final config = GeneratorConfig(
        name: 'Product',
        methods: ['get', 'update'],
        generateData: true,
        outputDir: secondDir.path,
        force: true,
      );
      await RepositoryPlugin(
        outputDir: secondDir.path,
        options: const GeneratorOptions(dryRun: false, force: true),
      ).generate(config);

      final first = await storeFor(tempDir).loadForEntity('Product');
      final second = await storeFor(outer).loadForEntity('Product');

      expect(first!.methodsSha256, second!.methodsSha256);
      expect(first.interface.sha256, second.interface.sha256);
      expect(first.implementation.sha256, second.implementation.sha256);
    });

    test('a failed conformance gate writes no manifest', () async {
      final config = GeneratorConfig(
        name: 'Product',
        methods: ['get', 'bogusVerb'],
        generateData: true,
        outputDir: outputDir,
        force: true,
      );
      await expectLater(plugin().generate(config), throwsA(anything));
      expect(storeFor(tempDir).fileFor('Product').existsSync(), isFalse);
    });
  });

  group('SourceInterfaceGuard consumes the manifest', () {
    late RepositoryContractManifest manifest;

    setUp(() async {
      await generatePair();
      manifest = (await storeFor(tempDir).loadForEntity('Product'))!;
    });

    Future<List<String>> filter(List<String> methods) async {
      final config = GeneratorConfig(
        name: 'Product',
        outputDir: outputDir,
        methods: ['get', 'update'],
      );
      return const SourceInterfaceGuard().filterMethods(
        config,
        methods: methods,
      );
    }

    test(
      'fresh manifest is the source of truth (wins over source parse)',
      () async {
        // The interface file declares get+update; the manifest records the
        // same. Filtering an unknown method must be dropped either way.
        final result = await filter(['get', 'update', 'nonexistent']);
        expect(result, ['get', 'update']);
      },
    );

    test(
      'hand-edited interface makes the manifest stale → source parse fallback',
      () async {
        final interfaceFile = File(
          '${tempDir.path}/lib/src/domain/repositories/product_repository.dart',
        );
        await interfaceFile.writeAsString(
          (await interfaceFile.readAsString()).replaceFirst(
            'abstract class ProductRepository {',
            'abstract class ProductRepository {\n  Future<void> custom();',
          ),
        );

        final result = await filter(['get', 'update', 'custom']);
        // Fallback re-parses the drifted source: custom() is now declared.
        expect(result, contains('custom'));
        expect(result, containsAll(['get', 'update']));
      },
    );

    test('divergent fresh manifest wins over what the source says', () async {
      // Hand-edit the interface, then re-record the manifest so it is
      // FRESH for the drifted file but declares only `get`. The guard must
      // trust the manifest (one source of truth), not the file text.
      final interfaceFile = File(
        '${tempDir.path}/lib/src/domain/repositories/product_repository.dart',
      );
      await interfaceFile.writeAsString(
        (await interfaceFile.readAsString()).replaceFirst(
          'abstract class ProductRepository {',
          'abstract class ProductRepository {\n  Future<void> custom();',
        ),
      );

      final driftedReader = RepositoryContractManifest(
        entity: 'Product',
        interface: RepositoryContractFile(
          className: 'ProductRepository',
          path: manifest.interface.path,
          sha256: repositoryContractDigest(await interfaceFile.readAsString()),
        ),
        implementation: manifest.implementation,
        methods: const [
          RepositoryContractMethod(
            name: 'get',
            returns: 'Future<Product>',
            params: ['QueryParams<Product> params'],
          ),
        ],
        methodsSha256: RepositoryContractManifest.hashOfMethods([
          const RepositoryContractMethod(
            name: 'get',
            returns: 'Future<Product>',
            params: ['QueryParams<Product> params'],
          ),
        ]),
        generatorVersion: 'test',
        at: DateTime.now().toUtc(),
      );
      await storeFor(tempDir).save(driftedReader);

      final result = await filter(['get', 'update', 'custom']);
      expect(result, ['get'], reason: 'fresh manifest overrides source text');
    });

    test(
      'corrupt manifest (tampered method table) falls back to source parse',
      () async {
        final file = storeFor(tempDir).fileFor('Product');
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        json['methods'] = [
          {'name': 'bogus', 'returns': 'void', 'params': <String>[]},
        ];
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(json),
        );

        final result = await filter(['get', 'update']);
        expect(result, [
          'get',
          'update',
        ], reason: 'integrity check fails → parse the interface instead');
      },
    );
  });

  group('zfa proof check integrates contract manifests', () {
    test('green on a fresh generation, red on hand-edit', () async {
      await generatePair();
      final checker = ProofChecker(projectRoot: tempDir.path);

      final green = await checker.check();
      expect(green.ok, isTrue, reason: '${green.findings}');

      // Hand-edit the implementation — the manifest digest no longer holds.
      final implFile = File(
        '${tempDir.path}/lib/src/data/repositories/data_product_repository.dart',
      );
      await implFile.writeAsString(
        '${await implFile.readAsString()}\n// hand edit\n',
      );

      final red = await checker.check();
      expect(red.ok, isFalse);
      expect(red.findings.map((f) => f.kind), contains('manifest_drift'));
    });

    test('red when the manifest method table is hand-edited', () async {
      await generatePair();
      final file = storeFor(tempDir).fileFor('Product');
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      (json['methods'] as List).removeAt(0);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(json),
      );

      final report = await ProofChecker(projectRoot: tempDir.path).check();
      expect(report.ok, isFalse);
      expect(report.findings.map((f) => f.kind), contains('manifest_corrupt'));
    });
  });
}
