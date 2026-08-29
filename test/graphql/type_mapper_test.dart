import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('TypeMapper', () {
    final mapper = TypeMapper();

    test('maps built-in scalars', () {
      expect(mapper.mapType(GraphQLScalarType(name: 'String')), 'String?');
      expect(mapper.mapType(GraphQLScalarType(name: 'Int')), 'int?');
      expect(mapper.mapType(GraphQLScalarType(name: 'Float')), 'double?');
      expect(mapper.mapType(GraphQLScalarType(name: 'Boolean')), 'bool?');
      expect(mapper.mapType(GraphQLScalarType(name: 'ID')), 'String?');
    });

    test('maps non-null types without nullable', () {
      final nonNullString = GraphQLNonNullType(
        ofType: GraphQLScalarType(name: 'String'),
      );
      expect(mapper.mapType(nonNullString), 'String');

      final nonNullInt = GraphQLNonNullType(
        ofType: GraphQLScalarType(name: 'Int'),
      );
      expect(mapper.mapType(nonNullInt), 'int');
    });

    test('maps list types', () {
      final listString = GraphQLListType(
        ofType: GraphQLScalarType(name: 'String'),
      );
      expect(mapper.mapType(listString), 'List<String?>');

      final nonNullListString = GraphQLNonNullType(
        ofType: GraphQLListType(
          ofType: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'String')),
        ),
      );
      expect(mapper.mapType(nonNullListString), 'List<String>');
    });

    test('maps object types', () {
      expect(
        mapper.mapType(GraphQLObjectType(name: 'Product', fields: const [])),
        'Product?',
      );
    });

    test('maps enum types', () {
      expect(
        mapper.mapType(GraphQLEnumType(name: 'CurrencyCode', values: const [])),
        'CurrencyCode?',
      );
    });

    test('maps union types', () {
      expect(
        mapper.mapType(
          GraphQLUnionType(name: 'OrderResult', possibleTypes: const []),
        ),
        'OrderResult?',
      );
    });

    test('custom scalar mapping', () {
      final customMapper = TypeMapper(customScalars: {'DateTime': 'DateTime'});
      expect(
        customMapper.mapType(GraphQLScalarType(name: 'DateTime')),
        'DateTime?',
      );
    });

    test('type overrides', () {
      final overrideMapper = TypeMapper(
        typeOverrides: {'Product': 'ProductDto'},
      );
      expect(
        overrideMapper.mapType(
          GraphQLObjectType(name: 'Product', fields: const []),
        ),
        'ProductDto?',
      );
    });

    test('enumValue converts SCREAMING_SNAKE_CASE to camelCase', () {
      expect(TypeMapper.enumValue('USD'), 'usd');
      expect(TypeMapper.enumValue('CREDIT_CARD'), 'creditCard');
      expect(TypeMapper.enumValue('IN_STOCK'), 'inStock');
    });
  });

  spec037();
}
/// Spec 037 — schema cache, introspection & type mapping extensions.
void spec037() {
  group('TypeMapper (spec 037)', () {
    test('DateTime maps to DateTime built-in (FR-005)', () {
      final mapper = TypeMapper();
      expect(mapper.mapType(GraphQLScalarType(name: 'DateTime')), 'DateTime?');
      expect(
        mapper.mapType(
          GraphQLNonNullType(ofType: GraphQLScalarType(name: 'DateTime')),
        ),
        'DateTime',
      );
    });

    test('scalarMap overrides built-in defaults (FR-006)', () {
      final mapper = TypeMapper(customScalars: {'Money': 'int'});
      expect(mapper.mapType(GraphQLScalarType(name: 'Money')), 'int?');
      // Overrides win over the built-in scalar table too.
      final mapper2 = TypeMapper(customScalars: {'DateTime': 'String'});
      expect(mapper2.mapType(GraphQLScalarType(name: 'DateTime')), 'String?');
    });

    test('unmapped custom scalars fall back to String (edge case)', () {
      final mapper = TypeMapper();
      expect(mapper.mapType(GraphQLScalarType(name: 'Money')), 'String?');
    });

    test('fromZfaConfig reads graphql.scalarMap from .zfa.json (FR-006)', () {
      final mapper = TypeMapper.fromZfaConfig({
        'graphql': {
          'scalarMap': {'Money': 'int', 'DateTime': 'String'},
        },
      });
      expect(mapper.mapType(GraphQLScalarType(name: 'Money')), 'int?');
      expect(mapper.mapType(GraphQLScalarType(name: 'DateTime')), 'String?');
    });

    test('fromZfaConfig with no graphql section yields defaults', () {
      final mapper = TypeMapper.fromZfaConfig({});
      expect(mapper.mapType(GraphQLScalarType(name: 'Money')), 'String?');
      expect(mapper.mapType(GraphQLScalarType(name: 'DateTime')), 'DateTime?');
    });

    test('malformed scalarMap entries throw clear errors (edge case)', () {
      expect(
        () => TypeMapper.fromZfaConfig({
          'graphql': {'scalarMap': ['not', 'a', 'map']},
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TypeMapper.fromZfaConfig({
          'graphql': {
            'scalarMap': {'Money': 42},
          },
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('list nullability follows the v5 wrapper convention', () {
      final mapper = TypeMapper();
      // [String]! — non-null list of nullable elements.
      expect(
        mapper.mapType(
          GraphQLNonNullType(
            ofType: GraphQLListType(ofType: GraphQLScalarType(name: 'String')),
          ),
        ),
        'List<String?>',
      );
      // [String!]! — non-null list of non-null elements.
      expect(
        mapper.mapType(
          GraphQLNonNullType(
            ofType: GraphQLListType(
              ofType: GraphQLNonNullType(
                ofType: GraphQLScalarType(name: 'String'),
              ),
            ),
          ),
        ),
        'List<String>',
      );
    });

    test('mapTypeRef renders GqlTypeRef chains (diff-side rendering)', () {
      final mapper = TypeMapper();
      expect(
        mapper.mapTypeRef(const GqlTypeRef(kind: GqlTypeKind.scalar, name: 'String')),
        'String?',
      );
      expect(
        mapper.mapTypeRef(const GqlTypeRef(
          kind: GqlTypeKind.nonNull,
          ofType: GqlTypeRef(kind: GqlTypeKind.scalar, name: 'String'),
        )),
        'String',
      );
      expect(
        mapper.mapTypeRef(const GqlTypeRef(
          kind: GqlTypeKind.list,
          ofType: GqlTypeRef(kind: GqlTypeKind.scalar, name: 'String'),
        )),
        'List<String?>',
      );
      expect(
        mapper.mapTypeRef(const GqlTypeRef(
          kind: GqlTypeKind.nonNull,
          ofType: GqlTypeRef(
            kind: GqlTypeKind.list,
            ofType: GqlTypeRef(
              kind: GqlTypeKind.nonNull,
              ofType: GqlTypeRef(kind: GqlTypeKind.scalar, name: 'String'),
            ),
          ),
        )),
        'List<String>',
      );
    });

    test('mapTypeRef applies scalarMap overrides', () {
      final mapper = TypeMapper(customScalars: {'Money': 'int'});
      expect(
        mapper.mapTypeRef(const GqlTypeRef(
          kind: GqlTypeKind.nonNull,
          ofType: GqlTypeRef(kind: GqlTypeKind.scalar, name: 'Money'),
        )),
        'int',
      );
    });

    test('unionRepresentation produces a sealed Dart hierarchy (FR-008)', () {
      final mapper = TypeMapper();
      final source = mapper.unionRepresentation(
        GraphQLUnionType(
          name: 'SearchResult',
          possibleTypes: const ['Product', 'ProductVariant'],
        ),
      );
      expect(source, contains('sealed class SearchResult'));
      expect(source, contains('extends SearchResult'));
      expect(source, contains('Product'));
      expect(source, contains('ProductVariant'));
      // All member types are accessible as typed values.
      expect(source, contains('final Product product;'));
      expect(source, contains('final ProductVariant productVariant;'));
    });

    test('interfaceRepresentation produces an abstract class (FR-008)', () {
      final mapper = TypeMapper();
      final source = mapper.interfaceRepresentation(
        GraphQLInterfaceType(
          name: 'Node',
          fields: const [
            GraphQLField(
              name: 'id',
              type: GraphQLNonNullType(
                ofType: GraphQLScalarType(name: 'ID'),
              ),
            ),
          ],
        ),
      );
      expect(source, contains('abstract class Node'));
      expect(source, contains('id'));
      // Non-null ID maps to a non-nullable String field.
      expect(source, contains('final String id;'));
    });
  });
}
