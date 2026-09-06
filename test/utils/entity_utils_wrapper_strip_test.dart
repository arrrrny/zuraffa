// Bug 1198 follow-up — phantom entity imports from generic flattening.
//
// Spec-1003 finding #7 (flagged there as "follow-up material for the mock
// plugin owners"): `EntityUtils.extractEntityTypes` flattened framework
// param wrappers — `QueryParams<Product>` became the phantom
// `QueryParamsProduct` — so the mock provider (service lane) emitted
// imports for `domain/entities/query_params_product/` and
// `data/mock/query_params_product_mock_data.dart`, files nobody
// generates. Discovered for real by the template self-hosting loop's
// compile tier while driving the canonical `zfa make` plugin order
// (service before mock): `dart analyze` failed with four
// `uri_does_not_exist` errors on the emitted provider.
//
// The fix strips framework param/contract wrappers BEFORE flattening, so
// the wrapper's type argument (the actual entity) is extracted.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/utils/entity_utils.dart';

void main() {
  group('extractEntityTypes — framework param wrappers (#1198 follow-up)', () {
    test('QueryParams<T> yields the type argument, not the flattened '
        'phantom', () {
      expect(EntityUtils.extractEntityTypes('QueryParams<Product>'), [
        'Product',
      ]);
    });

    test('ListQueryParams<T> yields the type argument', () {
      expect(EntityUtils.extractEntityTypes('ListQueryParams<Product>'), [
        'Product',
      ]);
    });

    test('other framework wrappers strip to their type argument', () {
      expect(EntityUtils.extractEntityTypes('Params<Order>'), ['Order']);
      expect(EntityUtils.extractEntityTypes('Filter<User>'), ['User']);
      expect(EntityUtils.extractEntityTypes('Sort<User>'), ['User']);
      expect(EntityUtils.extractEntityTypes('UpdateParams<User>'), ['User']);
      expect(EntityUtils.extractEntityTypes('DeleteParams<User>'), ['User']);
      expect(EntityUtils.extractEntityTypes('InitializationParams<User>'), [
        'User',
      ]);
    });

    test('plain and List-wrapped types behave as before', () {
      expect(EntityUtils.extractEntityTypes('Product'), ['Product']);
      expect(EntityUtils.extractEntityTypes('List<Product>'), ['Product']);
      expect(EntityUtils.extractEntityTypes('QueryParams'), isEmpty);
      expect(EntityUtils.extractEntityTypes('ListQueryParams'), isEmpty);
      expect(EntityUtils.extractEntityTypes('NoParams'), isEmpty);
      expect(EntityUtils.extractEntityTypes('int'), isEmpty);
    });

    test('List<QueryParams<T>> unwraps to the entity', () {
      expect(EntityUtils.extractEntityTypes('List<QueryParams<Product>>'), [
        'Product',
      ]);
    });
  });
}
