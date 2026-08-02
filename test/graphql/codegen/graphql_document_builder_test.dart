import 'package:gql/ast.dart' as ast;
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('GraphQLDocumentBuilder', () {
    final schema = GraphQLSchema(
      types: {
        'Query': GraphQLObjectType(
          name: 'Query',
          fields: [
            GraphQLField(
              name: 'product',
              type: GraphQLNonNullType(
                ofType: GraphQLObjectType(name: 'Product', fields: []),
              ),
              args: [
                GraphQLInputField(
                  name: 'id',
                  type: GraphQLNonNullType(
                    ofType: GraphQLScalarType(name: 'ID'),
                  ),
                ),
              ],
            ),
          ],
        ),
        'Product': GraphQLObjectType(
          name: 'Product',
          fields: [
            GraphQLField(
              name: 'id',
              type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
            ),
            GraphQLField(
              name: 'name',
              type: GraphQLNonNullType(
                ofType: GraphQLScalarType(name: 'String'),
              ),
            ),
          ],
        ),
        'ID': GraphQLScalarType(name: 'ID'),
        'String': GraphQLScalarType(name: 'String'),
      },
      queryTypeName: 'Query',
    );

    test('builds query document AST', () {
      final builder = GraphQLDocumentBuilder(schema: schema);
      final doc = builder.buildQueryDocument(
        operationName: 'GetProduct',
        fieldName: 'product',
        fields: ['id', 'name'],
        args: {'id': GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID'))},
      );

      expect(doc.definitions.length, 1);
      expect(doc.definitions.first, isA<ast.OperationDefinitionNode>());
    });

    test('serializes to GraphQL text', () {
      final builder = GraphQLDocumentBuilder(schema: schema);
      final doc = builder.buildQueryDocument(
        operationName: 'GetProduct',
        fieldName: 'product',
        fields: ['id', 'name'],
        args: {'id': GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID'))},
      );

      final text = builder.serialize(doc);
      expect(text.contains('query GetProduct'), true);
      expect(text.contains('\$id: ID!'), true);
      expect(text.contains('product(id: \$id)'), true);
      expect(text.contains('id'), true);
      expect(text.contains('name'), true);
    });

    test('unvalidated mode adds header comment', () {
      final builder = GraphQLDocumentBuilder(schema: schema, unvalidated: true);
      final doc = builder.buildQueryDocument(
        operationName: 'GetProduct',
        fieldName: 'product',
        fields: ['id'],
      );

      final text = builder.serialize(doc);
      expect(text.contains('# UNVALIDATED'), true);
    });

    test('builds mutation document AST', () {
      final builder = GraphQLDocumentBuilder(schema: schema);
      final doc = builder.buildMutationDocument(
        operationName: 'UpdateProduct',
        fieldName: 'updateProduct',
        fields: ['id', 'name'],
        inputVars: {
          'input': GraphQLNonNullType(
            ofType: GraphQLScalarType(name: 'String'),
          ),
        },
      );

      final text = builder.serialize(doc);
      expect(text.contains('mutation UpdateProduct'), true);
      expect(text.contains('\$input: String!'), true);
    });

    test('builds subscription document AST', () {
      final builder = GraphQLDocumentBuilder(schema: schema);
      final doc = builder.buildSubscriptionDocument(
        operationName: 'WatchProduct',
        fieldName: 'productUpdated',
        fields: ['id', 'name'],
        args: {'id': GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID'))},
      );

      final text = builder.serialize(doc);
      expect(text.contains('subscription WatchProduct'), true);
    });

    test('builds fragment document AST', () {
      final builder = GraphQLDocumentBuilder(schema: schema);
      final doc = builder.buildFragmentDocument(
        name: 'ProductFields',
        onType: 'Product',
        fields: ['id', 'name'],
      );

      final text = builder.serialize(doc);
      expect(text.contains('fragment ProductFields on Product'), true);
      expect(text.contains('id'), true);
      expect(text.contains('name'), true);
    });
  });
}
