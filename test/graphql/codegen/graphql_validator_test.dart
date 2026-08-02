import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('GraphQLValidator', () {
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

    test('validates correct document', () {
      final validator = GraphQLValidator(schema: schema);
      final doc = GraphQLDocumentBuilder(schema: schema).buildQueryDocument(
        operationName: 'GetProduct',
        fieldName: 'product',
        fields: ['id', 'name'],
        args: {'id': GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID'))},
      );

      final errors = validator.validate(doc);
      expect(
        errors.where((e) => e.severity == ValidationSeverity.error).isEmpty,
        true,
      );
    });

    test('detects unknown field', () {
      final validator = GraphQLValidator(schema: schema);
      final doc = GraphQLDocumentBuilder(schema: schema).buildQueryDocument(
        operationName: 'GetProduct',
        fieldName: 'product',
        fields: ['id', 'nonExistentField'],
      );

      final errors = validator.validate(doc);
      final fieldErrors = errors.where(
        (e) => e.message.contains('Unknown field'),
      );
      expect(fieldErrors.isNotEmpty, true);
    });

    test('detects unknown operation field', () {
      final validator = GraphQLValidator(schema: schema);
      final doc = GraphQLDocumentBuilder(schema: schema).buildQueryDocument(
        operationName: 'GetProduct',
        fieldName: 'nonExistentQuery',
        fields: ['id'],
      );

      final errors = validator.validate(doc);
      expect(errors.isNotEmpty, true);
    });
  });
}
