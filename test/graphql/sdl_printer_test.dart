import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/graphql/graphql_schema.dart';
import 'package:zuraffa/src/graphql/sdl/sdl_printer.dart';
import 'package:path/path.dart' as p;

import '../helpers/project_root.dart';

GqlSchema _loadFixture() {
  final raw = File(
    p.join(_fixturesDir, 'graphql', 'vendure_shop_introspection_v1.json'),
  ).readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return GqlSchema.fromIntrospection(json['data'] as Map<String, dynamic>);
}

late String _fixturesDir;

void main() {
  setUpAll(() async {
    _fixturesDir = p.join(await findProjectRoot(), 'test', 'fixtures');
  });

  group('SdlPrinter', () {
    test('renders the schema header with query and mutation roots', () {
      final sdl = SdlPrinter(_loadFixture()).printSchema();
      expect(sdl, contains('schema {'));
      expect(sdl, contains('query: Query'));
      expect(sdl, contains('mutation: Mutation'));
      // no subscription root in the fixture
      expect(sdl, isNot(contains('subscription:')));
    });

    test('renders object types with implements clause and fields', () {
      final sdl = SdlPrinter(_loadFixture()).printSchema();
      expect(sdl, contains('type Product implements Node {'));
      expect(sdl, contains('  id: ID!'));
      expect(sdl, contains('  name: String!'));
      expect(sdl, contains('  variants: [ProductVariant!]!'));
      expect(sdl, contains('  featuredAsset: Asset'));
      expect(sdl, contains('  createdAt: DateTime'));
      expect(sdl, contains('}'));
    });

    test('renders enums', () {
      final sdl = SdlPrinter(_loadFixture()).printSchema();
      expect(sdl, contains('enum SortOrder {'));
      expect(sdl, contains('  ASC'));
      expect(sdl, contains('  DESC'));
      expect(sdl, contains('enum CurrencyCode {'));
    });

    test('renders unions with all member types', () {
      final sdl = SdlPrinter(_loadFixture()).printSchema();
      expect(
        sdl,
        contains(
          'union AddItemToOrderResult = Order | OrderLine | '
          'InsufficientStockError | NegativeQuantityError | OrderOperationError',
        ),
      );
    });

    test('renders interfaces with fields', () {
      final sdl = SdlPrinter(_loadFixture()).printSchema();
      expect(sdl, contains('interface Node {'));
      expect(sdl, contains('interface ErrorResult {'));
      expect(sdl, contains('  errorCode: String!'));
    });

    test('renders custom scalars and skips built-in scalars', () {
      final sdl = SdlPrinter(_loadFixture()).printSchema();
      expect(sdl, contains('scalar DateTime'));
      expect(sdl, contains('scalar Money'));
      // Built-in spec scalars are not re-declared.
      expect(sdl, isNot(contains('scalar String')));
      expect(sdl, isNot(contains('scalar Boolean')));
      expect(sdl, isNot(contains('scalar Int')));
      expect(sdl, isNot(contains('scalar Float')));
      expect(sdl, isNot(contains('scalar ID')));
    });

    test('renders input objects', () {
      final sdl = SdlPrinter(_loadFixture()).printSchema();
      expect(sdl, contains('input ProductListOptions {'));
      expect(sdl, contains('  take: Int'));
    });

    test('renders field arguments', () {
      final sdl = SdlPrinter(_loadFixture()).printSchema();
      expect(
        sdl,
        contains(
          '  products(options: ProductListOptions, take: Int, '
          'skip: Int): [Product!]!',
        ),
      );
    });

    test('renders nested list wrappers correctly', () {
      final schema = GqlSchema.fromIntrospection({
        '__schema': {
          'queryType': {'name': 'Query'},
          'types': [
            {
              'kind': 'OBJECT',
              'name': 'Query',
              'fields': [
                {
                  'name': 'matrix',
                  'args': [],
                  'type': {
                    'kind': 'NON_NULL',
                    'ofType': {
                      'kind': 'LIST',
                      'ofType': {
                        'kind': 'LIST',
                        'ofType': {
                          'kind': 'NON_NULL',
                          'ofType': {'kind': 'SCALAR', 'name': 'Int'},
                        },
                      },
                    },
                  },
                },
              ],
            },
          ],
        },
      });
      final sdl = SdlPrinter(schema).printSchema();
      expect(sdl, contains('matrix: [[Int!]]!'));
    });
  });
}
