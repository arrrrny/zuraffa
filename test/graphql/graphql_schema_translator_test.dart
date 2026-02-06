import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/graphql/graphql_schema.dart';
import 'package:zuraffa/src/graphql/graphql_schema_translator.dart';

void main() {
  group('GraphQLSchemaTranslator', () {
    group('extractEntitySpecs', () {
      test('returns correct entities from schema', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'OBJECT',
                'name': 'Product',
                'fields': [
                  {
                    'name': 'id',
                    'type': {
                      'kind': 'NON_NULL',
                      'ofType': {'kind': 'SCALAR', 'name': 'ID'}
                    }
                  },
                  {
                    'name': 'name',
                    'type': {'kind': 'SCALAR', 'name': 'String'}
                  },
                ]
              },
              {
                'kind': 'OBJECT',
                'name': 'User',
                'fields': [
                  {
                    'name': 'id',
                    'type': {
                      'kind': 'NON_NULL',
                      'ofType': {'kind': 'SCALAR', 'name': 'ID'}
                    }
                  },
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final entities = translator.extractEntitySpecs();

        expect(entities, hasLength(2));
        expect(entities.map((e) => e.name), containsAll(['Product', 'User']));
      });

      test('maps scalar types correctly', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'OBJECT',
                'name': 'Item',
                'fields': [
                  {
                    'name': 'id',
                    'type': {
                      'kind': 'NON_NULL',
                      'ofType': {'kind': 'SCALAR', 'name': 'ID'}
                    }
                  },
                  {
                    'name': 'name',
                    'type': {'kind': 'SCALAR', 'name': 'String'}
                  },
                  {
                    'name': 'count',
                    'type': {'kind': 'SCALAR', 'name': 'Int'}
                  },
                  {
                    'name': 'price',
                    'type': {'kind': 'SCALAR', 'name': 'Float'}
                  },
                  {
                    'name': 'isActive',
                    'type': {'kind': 'SCALAR', 'name': 'Boolean'}
                  },
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final entities = translator.extractEntitySpecs();

        expect(entities, hasLength(1));
        final item = entities.first;
        expect(item.fields.firstWhere((f) => f.name == 'id').dartType, 'String');
        expect(item.fields.firstWhere((f) => f.name == 'name').dartType, 'String');
        expect(item.fields.firstWhere((f) => f.name == 'count').dartType, 'int');
        expect(item.fields.firstWhere((f) => f.name == 'price').dartType, 'double');
        expect(item.fields.firstWhere((f) => f.name == 'isActive').dartType, 'bool');
      });

      test('handles nullable vs non-null fields', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'OBJECT',
                'name': 'Product',
                'fields': [
                  {
                    'name': 'id',
                    'type': {
                      'kind': 'NON_NULL',
                      'ofType': {'kind': 'SCALAR', 'name': 'ID'}
                    }
                  },
                  {
                    'name': 'description',
                    'type': {'kind': 'SCALAR', 'name': 'String'}
                  },
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final entities = translator.extractEntitySpecs();

        final product = entities.first;
        final idField = product.fields.firstWhere((f) => f.name == 'id');
        final descField = product.fields.firstWhere((f) => f.name == 'description');

        expect(idField.isNullable, isFalse);
        expect(descField.isNullable, isTrue);
      });

      test('infers id field correctly', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'OBJECT',
                'name': 'Product',
                'fields': [
                  {
                    'name': 'id',
                    'type': {
                      'kind': 'NON_NULL',
                      'ofType': {'kind': 'SCALAR', 'name': 'ID'}
                    }
                  },
                  {
                    'name': 'name',
                    'type': {'kind': 'SCALAR', 'name': 'String'}
                  },
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final entities = translator.extractEntitySpecs();

        expect(entities.first.idField, 'id');
        expect(entities.first.idDartType, 'String');
      });

      test('infers entityNameId field when id is missing', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'OBJECT',
                'name': 'Order',
                'fields': [
                  {
                    'name': 'orderId',
                    'type': {
                      'kind': 'NON_NULL',
                      'ofType': {'kind': 'SCALAR', 'name': 'ID'}
                    }
                  },
                  {
                    'name': 'total',
                    'type': {'kind': 'SCALAR', 'name': 'Float'}
                  },
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final entities = translator.extractEntitySpecs();

        expect(entities.first.idField, 'orderId');
        expect(entities.first.idDartType, 'String');
      });

      test('include filter works', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'OBJECT',
                'name': 'Product',
                'fields': [
                  {
                    'name': 'id',
                    'type': {'kind': 'SCALAR', 'name': 'ID'}
                  },
                ]
              },
              {
                'kind': 'OBJECT',
                'name': 'User',
                'fields': [
                  {
                    'name': 'id',
                    'type': {'kind': 'SCALAR', 'name': 'ID'}
                  },
                ]
              },
              {
                'kind': 'OBJECT',
                'name': 'Order',
                'fields': [
                  {
                    'name': 'id',
                    'type': {'kind': 'SCALAR', 'name': 'ID'}
                  },
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final entities = translator.extractEntitySpecs(include: {'Product', 'User'});

        expect(entities, hasLength(2));
        expect(entities.map((e) => e.name), containsAll(['Product', 'User']));
        expect(entities.map((e) => e.name), isNot(contains('Order')));
      });

      test('exclude filter works', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'OBJECT',
                'name': 'Product',
                'fields': [
                  {
                    'name': 'id',
                    'type': {'kind': 'SCALAR', 'name': 'ID'}
                  },
                ]
              },
              {
                'kind': 'OBJECT',
                'name': 'User',
                'fields': [
                  {
                    'name': 'id',
                    'type': {'kind': 'SCALAR', 'name': 'ID'}
                  },
                ]
              },
              {
                'kind': 'OBJECT',
                'name': 'Order',
                'fields': [
                  {
                    'name': 'id',
                    'type': {'kind': 'SCALAR', 'name': 'ID'}
                  },
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final entities = translator.extractEntitySpecs(exclude: {'User'});

        expect(entities, hasLength(2));
        expect(entities.map((e) => e.name), containsAll(['Product', 'Order']));
        expect(entities.map((e) => e.name), isNot(contains('User')));
      });

      test('handles list fields', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'OBJECT',
                'name': 'Product',
                'fields': [
                  {
                    'name': 'id',
                    'type': {'kind': 'SCALAR', 'name': 'ID'}
                  },
                  {
                    'name': 'tags',
                    'type': {
                      'kind': 'LIST',
                      'ofType': {'kind': 'SCALAR', 'name': 'String'}
                    }
                  },
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final entities = translator.extractEntitySpecs();

        final tagsField = entities.first.fields.firstWhere((f) => f.name == 'tags');
        expect(tagsField.isList, isTrue);
        expect(tagsField.dartType, 'List<String>');
      });
    });

    group('extractEnumSpecs', () {
      test('returns correct enums with values', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'ENUM',
                'name': 'Status',
                'description': 'Product status',
                'enumValues': [
                  {'name': 'ACTIVE', 'description': 'Active item'},
                  {'name': 'INACTIVE', 'description': null},
                  {'name': 'PENDING', 'description': null},
                ]
              },
              {
                'kind': 'ENUM',
                'name': 'Priority',
                'enumValues': [
                  {'name': 'HIGH'},
                  {'name': 'MEDIUM'},
                  {'name': 'LOW'},
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final enums = translator.extractEnumSpecs();

        expect(enums, hasLength(2));

        final status = enums.firstWhere((e) => e.name == 'Status');
        expect(status.description, 'Product status');
        expect(status.values, ['ACTIVE', 'INACTIVE', 'PENDING']);

        final priority = enums.firstWhere((e) => e.name == 'Priority');
        expect(priority.values, ['HIGH', 'MEDIUM', 'LOW']);
      });

      test('include filter works for enums', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'ENUM',
                'name': 'Status',
                'enumValues': [
                  {'name': 'ACTIVE'},
                ]
              },
              {
                'kind': 'ENUM',
                'name': 'Priority',
                'enumValues': [
                  {'name': 'HIGH'},
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final enums = translator.extractEnumSpecs(include: {'Status'});

        expect(enums, hasLength(1));
        expect(enums.first.name, 'Status');
      });

      test('exclude filter works for enums', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'ENUM',
                'name': 'Status',
                'enumValues': [
                  {'name': 'ACTIVE'},
                ]
              },
              {
                'kind': 'ENUM',
                'name': 'Priority',
                'enumValues': [
                  {'name': 'HIGH'},
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final enums = translator.extractEnumSpecs(exclude: {'Status'});

        expect(enums, hasLength(1));
        expect(enums.first.name, 'Priority');
      });
    });

    group('custom scalar mappings', () {
      test('uses custom scalar mappings', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'OBJECT',
                'name': 'Event',
                'fields': [
                  {
                    'name': 'id',
                    'type': {'kind': 'SCALAR', 'name': 'ID'}
                  },
                  {
                    'name': 'data',
                    'type': {'kind': 'SCALAR', 'name': 'JSON'}
                  },
                  {
                    'name': 'timestamp',
                    'type': {'kind': 'SCALAR', 'name': 'Timestamp'}
                  },
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(
          schema,
          scalarMappings: {'Timestamp': 'int'},
        );
        final entities = translator.extractEntitySpecs();

        final dataField = entities.first.fields.firstWhere((f) => f.name == 'data');
        expect(dataField.dartType, 'Map<String, dynamic>');

        final timestampField = entities.first.fields.firstWhere((f) => f.name == 'timestamp');
        expect(timestampField.dartType, 'int');
      });
    });

    group('referenced entities', () {
      test('detects referenced entity types', () {
        final data = {
          '__schema': {
            'queryType': {'name': 'Query'},
            'mutationType': null,
            'subscriptionType': null,
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {
                'kind': 'OBJECT',
                'name': 'Order',
                'fields': [
                  {
                    'name': 'id',
                    'type': {'kind': 'SCALAR', 'name': 'ID'}
                  },
                  {
                    'name': 'customer',
                    'type': {'kind': 'OBJECT', 'name': 'Customer'}
                  },
                ]
              },
              {
                'kind': 'OBJECT',
                'name': 'Customer',
                'fields': [
                  {
                    'name': 'id',
                    'type': {'kind': 'SCALAR', 'name': 'ID'}
                  },
                ]
              },
            ]
          }
        };
        final schema = GqlSchema.fromIntrospection(data);
        final translator = GraphQLSchemaTranslator(schema);
        final entities = translator.extractEntitySpecs();

        final order = entities.firstWhere((e) => e.name == 'Order');
        final customerField = order.fields.firstWhere((f) => f.name == 'customer');

        expect(customerField.referencedEntity, 'Customer');
        expect(customerField.dartType, 'Customer');
      });
    });
  });
}
