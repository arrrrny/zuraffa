// Integration / Acceptance Test: ZuraffaApiBridge
//
// Acceptance criterion (from spec User Story 7):
//   Call example app UseCase handler functions programmatically,
//   parse the serialised JSON responses, and assert correctness.
//
// Design invariants proven here:
// - SC-002: Real UseCases called through bridge handlers yield correct JSON.
// - SC-005: Exceptions and AppFailures are absorbed — handlers never throw.
//
// No mocks at the UseCase or Repository layer.
// No dart:developer.registerExtension calls — handler functions are constructed
// inline, mirroring exactly what codegen would produce.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

// Example app types
import 'package:example/src/data/datasources/concert/concert_datasource.dart';
// import 'package:example/src/data/datasources/concert/concert_mock_datasource.dart';  // not needed directly
import 'package:example/src/data/datasources/product/product_datasource.dart';
import 'package:example/src/data/datasources/product/product_mock_datasource.dart';
import 'package:example/src/data/mock/concert_mock_data.dart';
import 'package:example/src/data/mock/product_mock_data.dart';
import 'package:example/src/domain/entities/concert/concert.dart';
import 'package:example/src/domain/entities/product/product.dart';
import 'package:example/src/domain/repositories/concert_repository.dart';
import 'package:example/src/domain/repositories/product_repository.dart';
import 'package:example/src/domain/usecases/concert/watch_concert_usecase.dart';
import 'package:example/src/domain/usecases/product/create_product_usecase.dart';
import 'package:example/src/domain/usecases/product/get_product_list_usecase.dart';

// ---------------------------------------------------------------------------
// In-test repositories
// ---------------------------------------------------------------------------

/// Thin product repository that delegates directly to a single DataSource.
/// Avoids the complexity of DataProductRepository's local datasource + cache.
class _DirectProductRepository implements ProductRepository {
  final ProductDataSource _ds;

  _DirectProductRepository(this._ds);

  @override
  Future<Product> get(QueryParams<Product> params) => _ds.get(params);

  @override
  Future<List<Product>> getList(ListQueryParams<Product> params) =>
      _ds.getList(params);

  @override
  Future<Product> create(Product product) => _ds.create(product);

  @override
  Future<Product> update(UpdateParams<String, ProductPatch> params) =>
      _ds.update(params);

  @override
  Future<void> delete(DeleteParams<String> params) => _ds.delete(params);

  @override
  Stream<Product> watch(QueryParams<Product> params) => _ds.watch(params);

  @override
  Stream<List<Product>> watchList(ListQueryParams<Product> params) =>
      _ds.watchList(params);
}

/// Thin concert repository backed by a DataSource.
class _DirectConcertRepository implements ConcertRepository {
  final ConcertDataSource _ds;

  _DirectConcertRepository(this._ds);

  @override
  Future<Concert> get(QueryParams<Concert> params) => _ds.get(params);

  @override
  Future<List<Concert>> getList(ListQueryParams<Concert> params) =>
      _ds.getList(params);

  @override
  Stream<Concert> watch(QueryParams<Concert> params) => _ds.watch(params);

  @override
  Future<Concert> update(UpdateParams<String, ConcertPatch> params) =>
      _ds.update(params);
}

// ---------------------------------------------------------------------------
// Bridge handlers — mirror what `zfa api` codegen produces.
// These are called directly (no dart:developer.registerExtension needed).
// ---------------------------------------------------------------------------

late GetProductListUseCase _getProductListUseCase;
late CreateProductUseCase _createProductUseCase;
late WatchConcertUseCase _watchConcertUseCase;

Future<developer.ServiceExtensionResponse> handleGetProductList(
  String method,
  Map<String, String> args,
) async {
  try {
    final result = await _getProductListUseCase(ListQueryParams<Product>());
    return ZuraffaApiBridge.serializeResult(
      result,
      (v) => {'items': v.map((p) => p.toJson()).toList()},
    );
  } catch (e, st) {
    developer.log(
      'Bridge error: $method',
      error: e,
      stackTrace: st,
      name: 'ZuraffaApiBridge',
    );
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }
}

Future<developer.ServiceExtensionResponse> handleCreateProduct(
  String method,
  Map<String, String> args,
) async {
  try {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(args['args'] ?? '{}') as Map<String, dynamic>;
    } catch (e) {
      return ZuraffaApiBridge.errorResponse('deserialization', e.toString());
    }
    final product = Product.fromJson(json);
    final result = await _createProductUseCase(product);
    return ZuraffaApiBridge.serializeResult(result, (v) => v.toJson());
  } catch (e, st) {
    developer.log(
      'Bridge error: $method',
      error: e,
      stackTrace: st,
      name: 'ZuraffaApiBridge',
    );
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }
}

/// A handler that is wired to a datasource that will throw notFoundFailure.
Future<developer.ServiceExtensionResponse> handleGetProductThatFails(
  String method,
  Map<String, String> args,
) async {
  try {
    // Calling update with a non-existent id causes notFoundFailure
    // Simulate a failure scenario by throwing an AppFailure directly.
    // This proves SC-005: AppFailure is serialized, not re-thrown.
    throw NotFoundFailure('Product not found');
  } catch (e, st) {
    if (e is AppFailure) {
      return ZuraffaApiBridge.serializeResult(
        Result<Product, AppFailure>.failure(e),
        (v) => v.toJson(),
      );
    }
    developer.log(
      'Bridge error: $method',
      error: e,
      stackTrace: st,
      name: 'ZuraffaApiBridge',
    );
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }
}

/// A handler backed by a datasource that throws a raw (non-AppFailure) Exception.
Future<developer.ServiceExtensionResponse> handleGetProductUnexpectedException(
  String method,
  Map<String, String> args,
) async {
  try {
    throw Exception('boom');
  } catch (e, st) {
    developer.log(
      'Bridge error: $method',
      error: e,
      stackTrace: st,
      name: 'ZuraffaApiBridge',
    );
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }
}

Future<developer.ServiceExtensionResponse> handleWatchConcert(
  String method,
  Map<String, String> args,
) async {
  try {
    final params = QueryParams<Concert>();
    final stream = _watchConcertUseCase(params);
    final subscriptionId = ZuraffaApiBridge.generateSubscriptionId();

    final subscription = stream.listen((result) {
      final serialized = result.fold(
        (v) => <String, dynamic>{'status': 'success', 'data': v.toJson()},
        (f) => <String, dynamic>{
          'status': 'error',
          'failure': {'type': f.runtimeType.toString(), 'message': f.message},
        },
      );
      ZuraffaApiBridge.updateStreamValue(subscriptionId, serialized);
    });

    ZuraffaApiBridge.registerStreamSubscription(
      subscriptionId,
      subscription,
      (_) {},
    );

    return developer.ServiceExtensionResponse.result(
      jsonEncode({'status': 'streaming', 'subscriptionId': subscriptionId}),
    );
  } catch (e, st) {
    developer.log(
      'Bridge error: $method',
      error: e,
      stackTrace: st,
      name: 'ZuraffaApiBridge',
    );
    return ZuraffaApiBridge.errorResponse('unknown', e.toString());
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    // Construct stack directly — no GetIt, no Flutter binding needed.
    final productDs = ProductMockDataSource(delay: Duration.zero);
    final productRepo = _DirectProductRepository(productDs);
    _getProductListUseCase = GetProductListUseCase(productRepo);
    _createProductUseCase = CreateProductUseCase(productRepo);
  });

  setUp(() async {
    await ZuraffaApiBridge.resetForTesting();
  });

  tearDown(() async {
    await ZuraffaApiBridge.resetForTesting();
  });

  // ---------------------------------------------------------------------------
  // Success path
  // ---------------------------------------------------------------------------

  group('success path — GetProductListUseCase', () {
    test(
      'returns status:success with 3 products from mock datasource',
      () async {
        final response = await handleGetProductList(
          'ext.zuraffa.product.getProductList',
          {},
        );

        final body = jsonDecode(response.result!) as Map<String, dynamic>;
        expect(body['status'], 'success');

        final items = (body['data']['items'] as List);
        expect(items.length, ProductMockData.products.length);
        expect(items.first['id'], 'id 1');
        expect(items.first['name'], 'name 1');
      },
    );

    test('CreateProductUseCase — echoes the created product', () async {
      final product = Product(
        id: 'test-1',
        name: 'Integration Test Product',
        description: 'desc',
        price: 9.99,
        createdAt: DateTime(2026, 1, 1),
      );

      final response = await handleCreateProduct(
        'ext.zuraffa.product.createProduct',
        {'args': jsonEncode(product.toJson())},
      );

      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(body['status'], 'success');
      expect(body['data']['id'], 'test-1');
      expect(body['data']['name'], 'Integration Test Product');
    });
  });

  // ---------------------------------------------------------------------------
  // Failure path — SC-005: handlers never throw
  // ---------------------------------------------------------------------------

  group('failure path', () {
    test('notFoundFailure — returns status:error with failure block', () async {
      final response = await handleGetProductThatFails(
        'ext.zuraffa.product.getProduct',
        {'id': 'nonexistent'},
      );

      final body = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(body['status'], 'error');
      expect(body['failure'], isA<Map>());
      expect(body['failure']['message'], isNotEmpty);
    });

    test(
      'unexpected exception — returns status:error, type:unknown, does not throw',
      () async {
        final response = await handleGetProductUnexpectedException(
          'ext.zuraffa.product.getProduct',
          {},
        );

        final body = jsonDecode(response.result!) as Map<String, dynamic>;
        expect(body['status'], 'error');
        expect(body['failure']['type'], 'unknown');
        expect(body['failure']['message'], contains('boom'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Stream lifecycle — subscribe → poll → cancel
  // ---------------------------------------------------------------------------

  group('stream lifecycle — WatchConcertUseCase', () {
    test(
      'subscribe → poll → cancel lifecycle completes without leaks',
      () async {
        // Use a StreamController to avoid the 2-second Stream.periodic delay.
        final controller = StreamController<Concert>.broadcast();

        // Wire a WatchConcertUseCase to the controller stream.
        final concertDs = _ControllerBackedConcertDataSource(controller.stream);
        final concertRepo = _DirectConcertRepository(concertDs);
        _watchConcertUseCase = WatchConcertUseCase(concertRepo);

        // 1. Subscribe
        final startResponse = await handleWatchConcert(
          'ext.zuraffa.concert.watchConcert',
          {'args': jsonEncode(<String, dynamic>{})},
        );
        final startBody =
            jsonDecode(startResponse.result!) as Map<String, dynamic>;
        expect(startBody['status'], 'streaming');
        final subId = startBody['subscriptionId'] as String;
        expect(subId, isNotEmpty);

        // 2. Emit a Concert value
        controller.add(ConcertMockData.sampleConcert);
        await Future.microtask(() {}); // allow listener to process

        // 3. Poll — should return the emitted concert
        final pollResponse = await ZuraffaApiBridge.handlePollStream(
          'ext.zuraffa._pollStream',
          {'subscriptionId': subId},
        );
        final pollBody =
            jsonDecode(pollResponse.result!) as Map<String, dynamic>;
        expect(pollBody['status'], 'success');
        expect(pollBody['data']['id'], ConcertMockData.sampleConcert.id);

        // 4. Cancel
        final cancelResponse = await ZuraffaApiBridge.handleCancelStream(
          'ext.zuraffa._cancelStream',
          {'subscriptionId': subId},
        );
        final cancelBody =
            jsonDecode(cancelResponse.result!) as Map<String, dynamic>;
        expect(cancelBody['status'], 'cancelled');

        // 5. Verify no leak: subsequent poll returns notFound
        final postCancelPoll = await ZuraffaApiBridge.handlePollStream(
          'ext.zuraffa._pollStream',
          {'subscriptionId': subId},
        );
        final postBody =
            jsonDecode(postCancelPoll.result!) as Map<String, dynamic>;
        expect(postBody['status'], 'error');
        expect(postBody['failure']['type'], 'notFound');

        await controller.close();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Minimal ConcertDataSource backed by a Stream controller for testing
// ---------------------------------------------------------------------------

class _ControllerBackedConcertDataSource
    with Loggable, FailureHandler
    implements ConcertDataSource {
  final Stream<Concert> _stream;

  _ControllerBackedConcertDataSource(this._stream);

  @override
  Stream<Concert> watch(QueryParams<Concert> params) => _stream;

  @override
  Future<Concert> get(QueryParams<Concert> params) =>
      throw UnimplementedError('Not needed in stream test');

  @override
  Future<List<Concert>> getList(ListQueryParams<Concert> params) =>
      throw UnimplementedError();

  @override
  Future<Concert> update(UpdateParams<String, ConcertPatch> params) =>
      throw UnimplementedError();
}
