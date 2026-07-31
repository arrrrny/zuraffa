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
      expect(
        code.contains('class \$Order extends \$\$AddItemToOrderResult'),
        true,
      );
      expect(
        code.contains(
          'class \$OrderModificationError extends \$\$AddItemToOrderResult',
        ),
        true,
      );
      expect(code.contains('fromJson'), true);
      expect(code.contains("case 'Order':"), true);
      expect(code.contains("case 'OrderModificationError':"), true);
      expect(code.contains('__typename'), true);
    });
  });
}
