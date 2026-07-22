// Place at: example/lib/src/api/bridges/product_api_bridge.dart
//
// Mirrors example/lib/src/api/bridges/todo_api_bridge.dart, registering the
// Product domain's UseCases so x-ray's overlay has more than one domain to
// show (the shipped example only wired up Todo). This is what
// `zfa api Product` would generate.

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;
import 'package:zuraffa/zuraffa.dart';

import '../../domain/entities/product/product.dart';
import '../../domain/usecases/product/create_product_usecase.dart';
import '../../domain/usecases/product/get_product_list_usecase.dart';
import '../../domain/usecases/product/get_product_usecase.dart';

final getIt = GetIt.instance;

void registerProductApiBridge() {
  if (kReleaseMode) return;
  if (kProfileMode && !Zuraffa.enableApiInProfile) return;

  ZuraffaApiBridge.registerEndpoint(
    endpoint: const ApiEndpoint(
      method: 'ext.zuraffa.product.getProduct',
      domain: 'product',
      usecase: 'getProduct',
      params: {'id': 'String'},
      returns: 'Product',
      isStream: false,
    ),
    handler: _handleGetProduct,
  );

  ZuraffaApiBridge.registerEndpoint(
    endpoint: const ApiEndpoint(
      method: 'ext.zuraffa.product.getProductList',
      domain: 'product',
      usecase: 'getProductList',
      params: {},
      returns: 'List<Product>',
      isStream: false,
    ),
    handler: _handleGetProductList,
  );

  ZuraffaApiBridge.registerEndpoint(
    endpoint: const ApiEndpoint(
      method: 'ext.zuraffa.product.createProduct',
      domain: 'product',
      usecase: 'createProduct',
      params: {'args': 'Product'},
      returns: 'Product',
      isStream: false,
    ),
    handler: _handleCreateProduct,
  );
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

Future<developer.ServiceExtensionResponse> _handleGetProduct(
  String method,
  Map<String, String> args,
) async {
  try {
    final id = args['id'];
    if (id == null || id.isEmpty) {
      return ZuraffaApiBridge.errorResponse('badRequest', 'id is required');
    }
    final params = QueryParams<Product>(filter: ProductFields.id.eq(id));
    final useCase = getIt<GetProductUseCase>();
    final result = await useCase(params);
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

Future<developer.ServiceExtensionResponse> _handleGetProductList(
  String method,
  Map<String, String> args,
) async {
  try {
    const params = ListQueryParams<Product>();
    final useCase = getIt<GetProductListUseCase>();
    final result = await useCase(params);
    return ZuraffaApiBridge.serializeResult(
      result,
      (v) => {'items': v.map((e) => e.toJson()).toList()},
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

/// Creates a Product from a JSON-encoded `args` parameter (x-ray's inline
/// form posts a plain `{name: text}` map for undeclared-shape params, so in
/// a real bridge you'd typically flatten fields like `todo_api_bridge.dart`
/// does rather than expecting a full JSON blob — shown here as the
/// JSON-blob variant to demonstrate both patterns across the two bridges).
Future<developer.ServiceExtensionResponse> _handleCreateProduct(
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
    json['id'] ??= '';
    json['createdAt'] ??= DateTime.now().toIso8601String();
    final params = Product.fromJson(json);
    final useCase = getIt<CreateProductUseCase>();
    final result = await useCase(params);
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
