import 'package:flutter_test/flutter_test.dart';
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
}
