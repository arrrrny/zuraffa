import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Golden: Full-Stack Generation', () {
    late Directory tempDir;

    setUp(
      () => tempDir = Directory.systemTemp.createTempSync('graphql_golden_'),
    );
    tearDown(() => tempDir.deleteSync(recursive: true));

    test('golden: generates entities, DTOs, unions, and DI', () {
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
          'ProductListOptions': GraphQLInputObjectType(
            name: 'ProductListOptions',
            inputFields: [
              GraphQLInputField(
                name: 'take',
                type: GraphQLScalarType(name: 'Int'),
              ),
            ],
          ),
          'AddItemToOrderResult': GraphQLUnionType(
            name: 'AddItemToOrderResult',
            possibleTypes: ['Order', 'OrderModificationError'],
          ),
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
          'ID': GraphQLScalarType(name: 'ID'),
          'String': GraphQLScalarType(name: 'String'),
          'Int': GraphQLScalarType(name: 'Int'),
        },
        queryTypeName: 'Query',
      );

      final orchestrator = SliceOrchestrator(
        schema: schema,
        outputDir: tempDir.path,
      );
      orchestrator.generateAll();

      // Assert entities generated
      final entityFile = File(p.join(tempDir.path, 'entities', 'product.dart'));
      expect(entityFile.existsSync(), true);
      final entityContent = entityFile.readAsStringSync();
      expect(entityContent.contains('class \$Product'), true);
      expect(entityContent.contains('fromJson'), true);
      expect(entityContent.contains('toJson'), true);

      // Assert DTOs generated
      final dtoFile = File(
        p.join(tempDir.path, 'dto', 'product_list_options.dart'),
      );
      expect(dtoFile.existsSync(), true);
      final dtoContent = dtoFile.readAsStringSync();
      expect(dtoContent.contains('class \$ProductListOptions'), true);
      expect(dtoContent.contains('toJson'), true);

      // Assert unions generated
      final unionFile = File(
        p.join(tempDir.path, 'unions', 'add_item_to_order_result.dart'),
      );
      expect(unionFile.existsSync(), true);
      final unionContent = unionFile.readAsStringSync();
      expect(unionContent.contains('sealed'), true);
      expect(unionContent.contains('__typename'), true);

      // Assert DI generated
      final diFile = File(p.join(tempDir.path, 'graphql_di.dart'));
      expect(diFile.existsSync(), true);
      final diContent = diFile.readAsStringSync();
      expect(diContent.contains('configureGraphqlDi'), true);
      expect(diContent.contains('ZuraffaContainer'), true);
    });

    test('golden: entity has correct nullability', () {
      final schema = GraphQLSchema(
        types: {
          'Product': GraphQLObjectType(
            name: 'Product',
            fields: [
              GraphQLField(
                name: 'id',
                type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
              ),
              GraphQLField(
                name: 'description',
                type: GraphQLScalarType(name: 'String'),
              ),
            ],
          ),
          'ID': GraphQLScalarType(name: 'ID'),
          'String': GraphQLScalarType(name: 'String'),
        },
      );

      final orchestrator = SliceOrchestrator(
        schema: schema,
        outputDir: tempDir.path,
      );
      orchestrator.generateAll();

      final content = File(
        p.join(tempDir.path, 'entities', 'product.dart'),
      ).readAsStringSync();
      expect(content.contains('final String id'), true); // non-null
      expect(content.contains('final String? description'), true); // nullable
    });
  });
}
