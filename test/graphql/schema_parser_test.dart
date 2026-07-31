import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('SchemaParser', () {
    test('parses simple introspection JSON', () {
      final json = {
        'data': {
          '__schema': {
            'queryType': {'name': 'Query'},
            'types': [
              {
                'kind': 'OBJECT',
                'name': 'Query',
                'fields': [
                  {
                    'name': 'product',
                    'type': {
                      'kind': 'NON_NULL',
                      'ofType': {'kind': 'OBJECT', 'name': 'Product'},
                    },
                    'args': [
                      {
                        'name': 'id',
                        'type': {
                          'kind': 'NON_NULL',
                          'ofType': {'kind': 'SCALAR', 'name': 'ID'},
                        },
                      },
                    ],
                  },
                ],
              },
              {
                'kind': 'OBJECT',
                'name': 'Product',
                'fields': [
                  {
                    'name': 'id',
                    'type': {
                      'kind': 'NON_NULL',
                      'ofType': {'kind': 'SCALAR', 'name': 'ID'},
                    },
                  },
                  {
                    'name': 'name',
                    'type': {
                      'kind': 'NON_NULL',
                      'ofType': {'kind': 'SCALAR', 'name': 'String'},
                    },
                  },
                  {
                    'name': 'price',
                    'type': {'kind': 'SCALAR', 'name': 'Int'},
                  },
                ],
              },
              {'kind': 'SCALAR', 'name': 'ID'},
              {'kind': 'SCALAR', 'name': 'String'},
              {'kind': 'SCALAR', 'name': 'Int'},
            ],
          },
        },
      };

      final schema = SchemaParser.parse(json);

      expect(schema.queryTypeName, 'Query');
      expect(schema.types.length, 5);
      expect(schema.getType('Product'), isA<GraphQLObjectType>());
      expect(schema.getType('ID'), isA<GraphQLScalarType>());
    });

    test('parses list types', () {
      final json = {
        'data': {
          '__schema': {
            'queryType': {'name': 'Query'},
            'types': [
              {
                'kind': 'OBJECT',
                'name': 'Query',
                'fields': [
                  {
                    'name': 'products',
                    'type': {
                      'kind': 'NON_NULL',
                      'ofType': {
                        'kind': 'LIST',
                        'ofType': {
                          'kind': 'NON_NULL',
                          'ofType': {'kind': 'OBJECT', 'name': 'Product'},
                        },
                      },
                    },
                    'args': [],
                  },
                ],
              },
              {
                'kind': 'OBJECT',
                'name': 'Product',
                'fields': [
                  {
                    'name': 'id',
                    'type': {
                      'kind': 'NON_NULL',
                      'ofType': {'kind': 'SCALAR', 'name': 'ID'},
                    },
                  },
                ],
              },
              {'kind': 'SCALAR', 'name': 'ID'},
            ],
          },
        },
      };

      final schema = SchemaParser.parse(json);
      final queryType = schema.getQueryType()!;
      final productsField = queryType.fields.first;

      expect(productsField.type, isA<GraphQLNonNullType>());
      expect(
        (productsField.type as GraphQLNonNullType).ofType,
        isA<GraphQLListType>(),
      );
      expect(productsField.type.dartType, 'List<Product>');
    });

    test('parses enum types', () {
      final json = {
        'data': {
          '__schema': {
            'types': [
              {
                'kind': 'ENUM',
                'name': 'CurrencyCode',
                'enumValues': [
                  {'name': 'USD'},
                  {'name': 'EUR'},
                  {'name': 'GBP'},
                ],
              },
            ],
          },
        },
      };

      final schema = SchemaParser.parse(json);
      final enumType = schema.getType('CurrencyCode') as GraphQLEnumType;

      expect(enumType.values, ['USD', 'EUR', 'GBP']);
      expect(enumType.dartType, 'CurrencyCode');
    });

    test('parses union types', () {
      final json = {
        'data': {
          '__schema': {
            'types': [
              {
                'kind': 'UNION',
                'name': 'AddItemToOrderResult',
                'possibleTypes': [
                  {'name': 'Order'},
                  {'name': 'OrderModificationError'},
                  {'name': 'InsufficientStockError'},
                ],
              },
              {'kind': 'OBJECT', 'name': 'Order', 'fields': []},
              {
                'kind': 'OBJECT',
                'name': 'OrderModificationError',
                'fields': [],
              },
              {
                'kind': 'OBJECT',
                'name': 'InsufficientStockError',
                'fields': [],
              },
            ],
          },
        },
      };

      final schema = SchemaParser.parse(json);
      final union = schema.getType('AddItemToOrderResult') as GraphQLUnionType;

      expect(union.possibleTypes, [
        'Order',
        'OrderModificationError',
        'InsufficientStockError',
      ]);
    });

    test('parses input object types', () {
      final json = {
        'data': {
          '__schema': {
            'types': [
              {
                'kind': 'INPUT_OBJECT',
                'name': 'ProductListOptions',
                'inputFields': [
                  {
                    'name': 'take',
                    'type': {'kind': 'SCALAR', 'name': 'Int'},
                  },
                  {
                    'name': 'skip',
                    'type': {'kind': 'SCALAR', 'name': 'Int'},
                  },
                ],
              },
            ],
          },
        },
      };

      final schema = SchemaParser.parse(json);
      final inputType =
          schema.getType('ProductListOptions') as GraphQLInputObjectType;

      expect(inputType.inputFields.length, 2);
      expect(inputType.inputFields.first.name, 'take');
      expect(inputType.inputFields.first.type.dartType, 'int?');
    });

    test('throws on invalid JSON', () {
      expect(
        () => SchemaParser.parse({'invalid': true}),
        throwsA(isA<SchemaParseError>()),
      );
    });
  });
}
