import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('DocumentBuilder', () {
    final builder = DocumentBuilder(
      schema: GraphQLSchema(types: {}, queryTypeName: 'Query'),
    );

    test('builds simple query', () {
      final doc = builder.buildQuery(
        operationName: 'GetProduct',
        fieldName: 'product',
        fields: ['id', 'name', 'price'],
        args: {'id': 'ID!'},
      );

      expect(doc.contains('query GetProduct(\$id: ID!)'), true);
      expect(doc.contains('product(id: \$id)'), true);
      expect(doc.contains('id'), true);
      expect(doc.contains('name'), true);
      expect(doc.contains('price'), true);
    });

    test('builds mutation with input variables', () {
      final doc = builder.buildMutation(
        operationName: 'AddItemToOrder',
        fieldName: 'addItemToOrder',
        fields: ['id', 'total'],
        inputVars: {'productVariantId': 'ID!', 'quantity': 'Int!'},
      );

      expect(doc.contains('mutation AddItemToOrder'), true);
      expect(doc.contains('\$productVariantId: ID!'), true);
      expect(doc.contains('\$quantity: Int!'), true);
      expect(
        doc.contains(
          'addItemToOrder(productVariantId: \$productVariantId, quantity: \$quantity)',
        ),
        true,
      );
    });

    test('builds subscription', () {
      final doc = builder.buildSubscription(
        operationName: 'OnOrderUpdated',
        fieldName: 'orderUpdated',
        fields: ['id', 'status'],
        args: {'id': 'ID!'},
      );

      expect(doc.contains('subscription OnOrderUpdated'), true);
      expect(doc.contains('orderUpdated(id: \$id)'), true);
    });

    test('builds fragment', () {
      final doc = builder.buildFragment(
        name: 'ProductFields',
        onType: 'Product',
        fields: ['id', 'name', 'price'],
      );

      expect(doc.contains('fragment ProductFields on Product'), true);
      expect(doc.contains('id'), true);
      expect(doc.contains('name'), true);
      expect(doc.contains('price'), true);
    });

    test('builds query without args', () {
      final doc = builder.buildQuery(
        operationName: 'GetAllProducts',
        fieldName: 'products',
        fields: ['id', 'name'],
      );

      expect(doc.contains('query GetAllProducts {'), true);
      expect(doc.contains('products {'), true);
    });
  });
}
