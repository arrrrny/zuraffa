import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('UnionGenerator', () {
    test('generates sealed class hierarchy', () {
      final schema = GraphQLSchema(
        types: {
          'Order': GraphQLObjectType(
            name: 'Order',
            fields: [
              GraphQLField(
                name: 'id',
                type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
              ),
            ],
          ),
          'OrderModificationError': GraphQLObjectType(
            name: 'OrderModificationError',
            fields: [
              GraphQLField(
                name: 'message',
                type: GraphQLNonNullType(
                  ofType: GraphQLScalarType(name: 'String'),
                ),
              ),
            ],
          ),
        },
      );

      final union = GraphQLUnionType(
        name: 'AddItemToOrderResult',
        possibleTypes: ['Order', 'OrderModificationError'],
      );

      final gen = UnionGenerator(typeMapper: TypeMapper(), schema: schema);
      final code = gen.generate(union);

      expect(code.contains('sealed class \$\$AddItemToOrderResult'), true);
      // Possible types are object entities — the generator reuses them via
      // imports instead of generating duplicate inline subclasses.
      expect(code.contains("import '../entities/order.dart';"), true);
      expect(
        code.contains("import '../entities/order_modification_error.dart';"),
        true,
      );
      expect(code.contains('fromJson'), true);
      expect(code.contains("case 'Order':"), true);
      expect(code.contains("case 'OrderModificationError':"), true);
      expect(code.contains('__typename'), true);
    });

    test('fromJson validates __typename presence', () {
      final schema = GraphQLSchema(
        types: {'Order': GraphQLObjectType(name: 'Order', fields: [])},
      );

      final union = GraphQLUnionType(
        name: 'TestResult',
        possibleTypes: ['Order'],
      );

      final gen = UnionGenerator(typeMapper: TypeMapper(), schema: schema);
      final code = gen.generate(union);

      expect(code.contains('Missing __typename in union JSON'), true);
      expect(code.contains('json[\'__typename\'] as String?'), true);
    });
  });
}
