import 'package:test/test.dart';

import 'package:zuraffa/src/core/api_endpoint.dart';

void main() {
  test('ApiEndpoint.toJson returns the exact catalog entry shape', () {
    const endpoint = ApiEndpoint(
      method: 'ext.zuraffa.product.getProduct',
      domain: 'product',
      usecase: 'getProduct',
      params: {'id': 'String'},
      returns: 'Product',
      isStream: false,
    );

    expect(endpoint.toJson(), {
      'method': 'ext.zuraffa.product.getProduct',
      'domain': 'product',
      'usecase': 'getProduct',
      'params': {'id': 'String'},
      'returns': 'Product',
      'isStream': false,
    });
  });
}
