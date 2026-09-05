// T005 (issue #970, FR-005 / AC-5 / A8): the provider-builder suite.
//
// `MockProviderBuilder` is 885 LOC of the mock plugin's core promise —
// "contract-conforming output" — yet had only 2 tests (both about the
// update-method Zorphy flag). This suite is characterization coverage of
// the BUILDER AS IT EXISTS (the spec forbids changing what gets
// generated): every test asserts generated file CONTENT, not just
// existence.
//
// Scenarios (validated against the real builder output before pinning):
// interface conformance (service mode), primitive canned values,
// list-of-primitives, entity-CRUD signatures, stream shapes,
// append-to-existing, lifecycle (init), void returns, and the negative
// cases (unknown method → ArgumentError; no service → the skip file; a
// missing interface → zero-member provider, the drift --certify refuses).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_provider_builder.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mpb_suite_970_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  MockProviderBuilder builder() => MockProviderBuilder(
    outputDir: outputDir,
    options: const GeneratorOptions(force: true),
  );

  /// Scaffolds a service interface the builder can extract methods from.
  Future<void> scaffoldService(String source) async {
    final dir = Directory(p.join(outputDir, 'domain', 'services'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'payment_service.dart')).writeAsString(source);
  }

  Future<String> generate(GeneratorConfig config) async {
    final file = await builder().generateMockProvider(config);
    expect(file.action, isNot('skip'), reason: 'the provider must generate');
    return file.content ?? '';
  }

  group('U7: service-mode interface conformance', () {
    test('A8-1: the provider implements the declared service with matching '
        'signatures, async for Futures and non-async for Streams', () async {
      await scaffoldService('''
import 'dart:async';

abstract class PaymentService {
  Future<String> processPayment(String params);
  Stream<double> watchRefunds(double params);
}
''');
      final content = await generate(
        GeneratorConfig(
          name: 'Payment',
          service: 'Payment',
          domain: 'payment',
          outputDir: outputDir,
        ),
      );

      // Class shape: the conformance contract.
      expect(content, contains('class PaymentMockProvider'));
      expect(content, contains('implements PaymentService'));
      expect(content, contains('with Loggable, FailureHandler'));

      // Interface member 1: async Future with the declared param type.
      expect(
        content,
        contains('Future<String> processPayment(String params) async'),
        reason:
            'Future members are implemented as async with the exact '
            'declared signature',
      );
      expect(content, contains("return 'mock_value';"));

      // Interface member 2: non-async Stream.
      expect(
        content,
        contains('Stream<double> watchRefunds(double params)'),
        reason: 'Stream members are implemented non-async',
      );
      expect(
        content,
        isNot(contains('Stream<double> watchRefunds(double params) async')),
      );
      expect(
        content,
        contains('Stream.fromFuture(Future.delayed(_delay, () => 1.0))'),
      );

      // The service interface import the mock certifies against.
      expect(
        content,
        contains("import '../../../domain/services/payment_service.dart';"),
      );
      // The canonical delay seam.
      expect(content, contains('const Duration(milliseconds: 100)'));
    });

    test(
      'A8-2: primitive returns emit the canned values (int 1, bool true)',
      () async {
        await scaffoldService('''
import 'dart:async';

abstract class PaymentService {
  Future<int> count(String params);
  Future<bool> isReady(String params);
}
''');
        final content = await generate(
          GeneratorConfig(
            name: 'Payment',
            service: 'Payment',
            outputDir: outputDir,
          ),
        );
        expect(content, contains('Future<int> count(String params) async'));
        expect(content, contains('return 1;'));
        expect(content, contains('Future<bool> isReady(String params) async'));
        expect(content, contains('return true;'));
      },
    );

    test('A8-3: a list-of-primitives return emits the empty list, and a void '
        'return emits Future.value()', () async {
      await scaffoldService('''
import 'dart:async';

abstract class PaymentService {
  Future<List<String>> names(String params);
  Future<void> ping(String params);
}
''');
      final content = await generate(
        GeneratorConfig(
          name: 'Payment',
          service: 'Payment',
          outputDir: outputDir,
        ),
      );
      expect(
        content,
        contains('Future<List<String>> names(String params) async'),
      );
      expect(
        content,
        contains('return [];'),
        reason: 'list-of-primitives returns the empty list',
      );
      expect(content, contains('Future<void> ping(String params) async'));
      expect(
        content,
        contains('return Future.value();'),
        reason: 'void members return Future.value()',
      );
    });

    test('A8-3b: a DateTime return emits DateTime.now (the canned value '
        'for the edge-case temporal type)', () async {
      await scaffoldService('''
import 'dart:async';

abstract class PaymentService {
  Future<DateTime> lastPaid(String params);
}
''');
      final content = await generate(
        GeneratorConfig(
          name: 'Payment',
          service: 'Payment',
          outputDir: outputDir,
        ),
      );
      expect(content, contains('Future<DateTime> lastPaid(String params)'));
      expect(
        content,
        contains('return DateTime.now();'),
        reason: 'DateTime members return the now-canned value',
      );
    });
  });

  group('U8: entity-CRUD mode', () {
    test('A8-4: CRUD members carry the canonical params types and the '
        'entity mock-data fixtures', () async {
      final content = await generate(
        GeneratorConfig(
          name: 'Product',
          service: 'Product',
          domain: 'product',
          methods: const [
            'get',
            'getList',
            'create',
            'delete',
            'watch',
            'watchList',
          ],
          outputDir: outputDir,
        ),
      );

      expect(content, contains('class ProductMockProvider'));
      expect(content, contains('implements ProductService'));
      // Entity + mock-data imports.
      expect(
        content,
        contains("import '../../../domain/entities/product/product.dart';"),
      );
      expect(content, contains("import '../../mock/product_mock_data.dart';"));

      // get / getList: the query surfaces with the fixture returns.
      expect(
        content,
        contains('Future<Product> get(QueryParams<Product> params) async'),
      );
      expect(content, contains('return ProductMockData.sampleProduct;'));
      expect(
        content,
        contains(
          'Future<List<Product>> getList(ListQueryParams<Product> params) '
          'async',
        ),
      );
      expect(content, contains('return ProductMockData.sampleList;'));

      // create echoes the item; delete is a void member.
      expect(content, contains('Future<Product> create(Product item) async'));
      expect(content, contains('return item;'));
      expect(
        content,
        contains('Future<void> delete(DeleteParams<String> params) async'),
      );

      // watch / watchList: the stream surfaces.
      expect(
        content,
        contains('Stream<Product> watch(QueryParams<Product> params)'),
      );
      expect(
        content,
        contains(
          'Stream<List<Product>> watchList('
          'ListQueryParams<Product> params)',
        ),
      );
      expect(
        content,
        contains(
          'Stream.fromFuture(\n'
          '      Future.delayed(_delay, () => ProductMockData.sampleProduct),'
          '\n    )',
        ),
        reason: 'the watch members stream the fixture after the delay',
      );
    });
  });

  group('U8: append-to-existing', () {
    test('A8-5: appendToExisting keeps the hand-written members and adds the '
        'interface members + the missing import', () async {
      await scaffoldService('''
import 'dart:async';

abstract class PaymentService {
  Future<String> processPayment(String params);
}
''');
      // A previously generated file that also carries a hand-written
      // member the regenerating run must preserve.
      final providerPath = p.join(
        outputDir,
        'data',
        'providers',
        'payment',
        'payment_mock_provider.dart',
      );
      await File(providerPath).parent.create(recursive: true);
      await File(providerPath).writeAsString('''
// GENERATED - DO NOT EDIT
// Generated by zfa for: Payment
import 'dart:async';

import 'package:zuraffa/mock.dart';

import '../../../domain/services/payment_service.dart';

/// Mock provider for PaymentService
class PaymentMockProvider
    with Loggable, FailureHandler
    implements PaymentService {
  PaymentMockProvider([Duration? delay])
    : _delay = delay ?? const Duration(milliseconds: 100);

  final Duration _delay;

  @override
  Future<int> customCount(String params) async {
    return 7;
  }
}

// END GENERATED
''');

      final file = await builder().generateMockProvider(
        GeneratorConfig(
          name: 'Payment',
          service: 'Payment',
          appendToExisting: true,
          outputDir: outputDir,
        ),
      );
      expect(file.action, 'overwritten');
      final content = file.content ?? '';

      // The hand-written member SURVIVES the append.
      expect(
        content,
        contains('Future<int> customCount(String params) async'),
        reason: 'append never drops existing members',
      );
      expect(content, contains('return 7;'));

      // The interface member is ADDED (exactly once).
      expect(
        content,
        contains('Future<String> processPayment(String params) async'),
      );
      expect(
        'processPayment(String params)'.allMatches(content).length,
        1,
        reason: 'append dedupes the member it adds',
      );

      // The mock-data import is appended for the fixtures the new
      // members reference.
      expect(content, contains("import '../../mock/payment_mock_data.dart';"));
    });
  });

  group('U8: lifecycle + negative cases', () {
    test('A8-6: generateInit emits the initialize/isInitialized/dispose '
        'lifecycle with the documented bodies', () async {
      await scaffoldService('''
import 'dart:async';

abstract class PaymentService {
  Future<void> ping(String params);
}
''');
      final content = await generate(
        GeneratorConfig(
          name: 'Payment',
          service: 'Payment',
          generateInit: true,
          outputDir: outputDir,
        ),
      );
      expect(
        content,
        contains('Future<void> initialize(InitializationParams params)'),
      );
      expect(
        content,
        contains('Stream<bool> get isInitialized => Stream.value(true);'),
      );
      expect(content, contains('Future<void> dispose()'));
      expect(content, contains('Future<void> ping(String params) async'));
    });

    test('A8-7 (negative): an unknown entity method is refused with an '
        'ArgumentError naming it', () async {
      await expectLater(
        builder().generateMockProvider(
          GeneratorConfig(
            name: 'Product',
            service: 'Product',
            methods: const ['frobnicate'],
            outputDir: outputDir,
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Unknown entity method: frobnicate'),
          ),
        ),
      );
    });

    test('A8-8 (negative): no service/useService skips generation with the '
        'skip contract (empty path, action skip)', () async {
      final file = await builder().generateMockProvider(
        GeneratorConfig(name: 'Product', outputDir: outputDir),
      );
      expect(file.action, 'skip');
      expect(file.path, isEmpty);
      expect(file.content ?? '', isEmpty);
    });

    test('A8-9 (negative): a missing service interface yields a zero-member '
        'provider — the exact drift `--certify` refuses', () async {
      // No service file scaffolded: MethodExtractor finds nothing, and
      // the builder emits the implements clause with zero members.
      final content = await generate(
        GeneratorConfig(
          name: 'Payment',
          service: 'Payment',
          outputDir: outputDir,
        ),
      );
      expect(content, contains('class PaymentMockProvider'));
      expect(content, contains('implements PaymentService'));
      expect(
        RegExp(r'@override').allMatches(content).length,
        0,
        reason:
            'no interface members were extracted, so no members are '
            'implemented — the drift the --certify gate refuses',
      );
    });
  });
}
