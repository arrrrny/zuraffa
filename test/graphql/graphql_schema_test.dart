import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/graphql/graphql_schema.dart';

void main() {
  group('GqlTypeRef', () {
    test('parses scalar type', () {
      final json = {'kind': 'SCALAR', 'name': 'String'};
      final typeRef = GqlTypeRef.fromJson(json);

      expect(typeRef.kind, GqlTypeKind.scalar);
      expect(typeRef.name, 'String');
      expect(typeRef.ofType, isNull);
    });

    test('parses non-null type wrapping scalar', () {
      final json = {
        'kind': 'NON_NULL',
        'ofType': {'kind': 'SCALAR', 'name': 'String'}
      };
      final typeRef = GqlTypeRef.fromJson(json);

      expect(typeRef.kind, GqlTypeKind.nonNull);
      expect(typeRef.isNonNull, isTrue);
      expect(typeRef.name, isNull);
      expect(typeRef.ofType, isNotNull);
      expect(typeRef.ofType!.kind, GqlTypeKind.scalar);
      expect(typeRef.ofType!.name, 'String');
    });

    test('parses list type', () {
      final json = {
        'kind': 'LIST',
        'ofType': {'kind': 'SCALAR', 'name': 'Int'}
      };
      final typeRef = GqlTypeRef.fromJson(json);

      expect(typeRef.kind, GqlTypeKind.list);
      expect(typeRef.isList, isTrue);
      expect(typeRef.listElementType, isNotNull);
      expect(typeRef.listElementType!.name, 'Int');
    });

    test('parses non-null list type', () {
      final json = {
        'kind': 'NON_NULL',
        'ofType': {
          'kind': 'LIST',
          'ofType': {'kind': 'SCALAR', 'name': 'String'}
        }
      };
      final typeRef = GqlTypeRef.fromJson(json);

      expect(typeRef.isNonNull, isTrue);
      expect(typeRef.isList, isTrue);
      expect(typeRef.listElementType!.name, 'String');
    });

    test('namedType getter unwraps correctly', () {
      final json = {
        'kind': 'NON_NULL',
        'ofType': {
          'kind': 'LIST',
          'ofType': {
            'kind': 'NON_NULL',
            'ofType': {'kind': 'OBJECT', 'name': 'Product'}
          }
        }
      };
      final typeRef = GqlTypeRef.fromJson(json);

      expect(typeRef.namedType.name, 'Product');
      expect(typeRef.namedType.kind, GqlTypeKind.object);
    });

    test('isNonNull returns false for nullable types', () {
      final json = {'kind': 'SCALAR', 'name': 'String'};
      final typeRef = GqlTypeRef.fromJson(json);

      expect(typeRef.isNonNull, isFalse);
    });

    test('isList returns false for non-list types', () {
      final json = {'kind': 'SCALAR', 'name': 'String'};
      final typeRef = GqlTypeRef.fromJson(json);

      expect(typeRef.isList, isFalse);
    });
  });

  group('GqlSchema', () {
    test('parses introspection result with queryType and mutationType', () {
      final data = {
        '__schema': {
          'queryType': {'name': 'Query'},
          'mutationType': {'name': 'Mutation'},
          'subscriptionType': null,
          'types': [
            {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
            {'kind': 'OBJECT', 'name': 'Mutation', 'fields': []},
          ]
        }
      };
      final schema = GqlSchema.fromIntrospection(data);

      expect(schema.queryTypeName, 'Query');
      expect(schema.mutationTypeName, 'Mutation');
      expect(schema.subscriptionTypeName, isNull);
      expect(schema.types, hasLength(2));
    });

    test('entityTypes excludes Query, Mutation, and built-in types', () {
      final data = {
        '__schema': {
          'queryType': {'name': 'Query'},
          'mutationType': {'name': 'Mutation'},
          'subscriptionType': null,
          'types': [
            {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
            {'kind': 'OBJECT', 'name': 'Mutation', 'fields': []},
            {'kind': 'OBJECT', 'name': '__Schema', 'fields': []},
            {'kind': 'OBJECT', 'name': '__Type', 'fields': []},
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
                }
              ]
            },
            {
              'kind': 'OBJECT',
              'name': 'User',
              'fields': [
                {
                  'name': 'id',
                  'type': {'kind': 'SCALAR', 'name': 'ID'}
                }
              ]
            },
          ]
        }
      };
      final schema = GqlSchema.fromIntrospection(data);
      final entityNames = schema.entityTypes.map((e) => e.name).toList();

      expect(entityNames, containsAll(['Product', 'User']));
      expect(entityNames, isNot(contains('Query')));
      expect(entityNames, isNot(contains('Mutation')));
      expect(entityNames, isNot(contains('__Schema')));
      expect(entityNames, isNot(contains('__Type')));
      expect(entityNames, hasLength(2));
    });

    test('enumTypes returns only enum types', () {
      final data = {
        '__schema': {
          'queryType': {'name': 'Query'},
          'mutationType': null,
          'subscriptionType': null,
          'types': [
            {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
            {'kind': 'OBJECT', 'name': 'Product', 'fields': []},
            {
              'kind': 'ENUM',
              'name': 'Status',
              'enumValues': [
                {'name': 'ACTIVE'},
                {'name': 'INACTIVE'},
              ]
            },
            {
              'kind': 'ENUM',
              'name': 'Priority',
              'enumValues': [
                {'name': 'HIGH'},
                {'name': 'LOW'},
              ]
            },
            {
              'kind': 'ENUM',
              'name': '__DirectiveLocation',
              'enumValues': [
                {'name': 'QUERY'},
              ]
            },
          ]
        }
      };
      final schema = GqlSchema.fromIntrospection(data);
      final enumNames = schema.enumTypes.map((e) => e.name).toList();

      expect(enumNames, containsAll(['Status', 'Priority']));
      expect(enumNames, isNot(contains('__DirectiveLocation')));
      expect(enumNames, isNot(contains('Product')));
      expect(enumNames, hasLength(2));
    });
  });

  group('GqlTypeDef', () {
    test('isBuiltIn returns true for types starting with __', () {
      final typeDef = GqlTypeDef.fromJson({
        'kind': 'OBJECT',
        'name': '__Schema',
        'fields': [],
      });

      expect(typeDef.isBuiltIn, isTrue);
    });

    test('isBuiltIn returns false for regular types', () {
      final typeDef = GqlTypeDef.fromJson({
        'kind': 'OBJECT',
        'name': 'Product',
        'fields': [],
      });

      expect(typeDef.isBuiltIn, isFalse);
    });
  });

  group('GqlField', () {
    test('parses field with description', () {
      final field = GqlField.fromJson({
        'name': 'title',
        'description': 'The product title',
        'type': {'kind': 'SCALAR', 'name': 'String'},
      });

      expect(field.name, 'title');
      expect(field.description, 'The product title');
      expect(field.type.name, 'String');
    });
  });

  group('GqlEnumValue', () {
    test('parses enum value', () {
      final value = GqlEnumValue.fromJson({
        'name': 'ACTIVE',
        'description': 'Active status',
      });

      expect(value.name, 'ACTIVE');
      expect(value.description, 'Active status');
    });
  });
}
