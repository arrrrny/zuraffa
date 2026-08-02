import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('Golden: Track 3.5 — gql Plugin', () {
    late Directory tempDir;

    setUp(() => tempDir = Directory.systemTemp.createTempSync('gql_golden_'));
    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
      'golden: generates .graphql file from AST, validates, preserves edits',
      () {
        final schema = _testSchema();
        final docBuilder = GraphQLDocumentBuilder(schema: schema);
        final preserver = GqlFilePreserver(schema: schema);

        // Step 1: Generate .graphql file
        final doc = docBuilder.buildQueryDocument(
          operationName: 'GetProduct',
          fieldName: 'product',
          fields: ['id', 'name'],
          args: {
            'id': GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
          },
        );
        final content = docBuilder.serialize(doc);

        final filePath = '${tempDir.path}/get_product.graphql';
        final action = preserver.decide(filePath, content);
        expect(action, PreserverAction.generate);

        // Write the file
        File(filePath).writeAsStringSync(content);

        // Step 2: Validate the generated file
        final validator = GraphQLValidator(schema: schema);
        final errors = validator.validate(doc);
        expect(
          errors.where((e) => e.severity == ValidationSeverity.error).isEmpty,
          true,
        );

        // Step 3: User edits the file
        final userEdit = content.replaceFirst('name', 'name\n    description');
        File(filePath).writeAsStringSync(userEdit);

        // Step 4: Regenerate — should preserve because still valid
        final action2 = preserver.decide(filePath, content);
        expect(action2, PreserverAction.preserve);

        // Step 5: --force reclaims ownership
        final action3 = preserver.decide(filePath, content, force: true);
        expect(action3, PreserverAction.overwrite);
      },
    );

    test('golden: documents.dart generated from .graphql files', () {
      final schema = _testSchema();
      final docBuilder = GraphQLDocumentBuilder(schema: schema);
      final docsGen = DocumentsDartGenerator();

      // Create two .graphql files
      final doc1 = docBuilder.buildQueryDocument(
        operationName: 'GetProduct',
        fieldName: 'product',
        fields: ['id', 'name'],
      );
      File(
        '${tempDir.path}/get_product.graphql',
      ).writeAsStringSync(docBuilder.serialize(doc1));

      final doc2 = docBuilder.buildMutationDocument(
        operationName: 'UpdateProduct',
        fieldName: 'updateProduct',
        fields: ['id'],
        inputVars: {
          'input': GraphQLNonNullType(
            ofType: GraphQLScalarType(name: 'String'),
          ),
        },
      );
      File(
        '${tempDir.path}/update_product.graphql',
      ).writeAsStringSync(docBuilder.serialize(doc2));

      // Generate documents.dart
      final code = docsGen.generate(
        graphqlDir: tempDir.path,
        outputPath: '${tempDir.path}/documents.dart',
      );

      expect(code.contains('getProductDocument'), true);
      expect(code.contains('updateProductDocument'), true);
      expect(code.contains('DocumentNode'), true);
      expect(code.contains('gql('), true);
      expect(code.contains('GENERATED CODE'), true);
      expect(code.contains('DO NOT EDIT BY HAND'), true);
    });

    test('golden: datasource uses DocumentNode from documents.dart', () {
      final gen = DatasourceGenerator(
        typeMapper: TypeMapper(),
        documentsImportPath: 'graphql/documents.dart',
      );

      final code = gen.generate(
        name: 'Product',
        queries: [
          QueryConfig(
            fieldName: 'product',
            returnType: GraphQLNonNullType(
              ofType: GraphQLObjectType(name: 'Product', fields: []),
            ),
            args: [
              GraphQLInputField(
                name: 'id',
                type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
              ),
            ],
            document: '',
          ),
        ],
        mutations: [],
      );

      expect(code.contains("import 'graphql/documents.dart';"), true);
      expect(code.contains('productDocument'), true);
      expect(code.contains('document: productDocument'), true);
      expect(code.contains("gql(r'''"), false); // No inline gql strings
    });

    test('golden: unvalidated fallback mode', () {
      final docBuilder = GraphQLDocumentBuilder(
        schema: _testSchema(),
        unvalidated: true,
      );
      final doc = docBuilder.buildQueryDocument(
        operationName: 'GetProduct',
        fieldName: 'product',
        fields: ['id'],
      );

      final text = docBuilder.serialize(doc);
      expect(text.contains('# UNVALIDATED'), true);
      expect(text.contains('no schema cache available'), true);
    });
  });
}

GraphQLSchema _testSchema() {
  return GraphQLSchema(
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
                type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
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
            type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'String')),
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
    queryTypeName: 'Query',
  );
}
