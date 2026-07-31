import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('EntityGenerator', () {
    final mapper = TypeMapper();
    final gen = EntityGenerator(typeMapper: mapper);

    test('generates entity with scalar fields', () {
      final type = GraphQLObjectType(
        name: 'Product',
        fields: [
          GraphQLField(
            name: 'id',
            type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
          ),
          GraphQLField(
            name: 'name',
            type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'String')),
          ),
          GraphQLField(
            name: 'price',
            type: GraphQLScalarType(name: 'Int'),
          ),
        ],
      );

      final code = gen.generate(type);
      expect(code.contains('class \$Product'), true);
      expect(code.contains('final String id'), true);
      expect(code.contains('final String name'), true);
      expect(code.contains('final int? price'), true);
      expect(code.contains('fromJson'), true);
      expect(code.contains('toJson'), true);
      expect(code.contains('copyWith'), true);
    });

    test('generates entity with nested object fields', () {
      final type = GraphQLObjectType(
        name: 'Order',
        fields: [
          GraphQLField(
            name: 'id',
            type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
          ),
          GraphQLField(
            name: 'lines',
            type: GraphQLNonNullType(
              ofType: GraphQLListType(
                ofType: GraphQLNonNullType(
                  ofType: GraphQLObjectType(name: 'OrderLine', fields: []),
                ),
              ),
            ),
          ),
        ],
      );

      final code = gen.generate(type);
      expect(code.contains('final List<\$OrderLine> lines'), true);
      expect(code.contains('\$OrderLine.fromJson'), true);
    });

    test('skips deprecated fields', () {
      final type = GraphQLObjectType(
        name: 'Product',
        fields: [
          GraphQLField(
            name: 'id',
            type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
          ),
          GraphQLField(
            name: 'oldField',
            type: GraphQLScalarType(name: 'String'),
            isDeprecated: true,
          ),
        ],
      );

      final code = gen.generate(type);
      expect(code.contains('final String id'), true);
      expect(code.contains('oldField'), false);
    });
  });
}
