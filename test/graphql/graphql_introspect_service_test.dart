import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

import '../helpers/project_root.dart';

/// Project-root-resolved `test/fixtures` directory. Resolved via
/// [findProjectRoot] (CWD-independent) because the test runner may set
/// CWD to the target directory when invoked as `dart test test` — the
/// old relative `test/fixtures/...` lookup broke under that invocation
/// and fell back to a hardcoded `/workspace/zuraffa/...` path that only
/// exists in the sandbox, not on GitHub Actions.
late String _fixturesDir;

/// Reads a fixture file from the project root's test/fixtures/ directory.
String _fixture(String name) =>
    File(p.join(_fixturesDir, name)).readAsStringSync();

void main() {
  setUpAll(() async {
    _fixturesDir = p.join(await findProjectRoot(), 'test', 'fixtures');
  });

  group('GraphQLIntrospectionService', () {
    test('introspect returns null for invalid URL', () async {
      final result = await GraphQLIntrospectionService.introspect(
        url: 'not-a-valid-url',
      );
      expect(result, isNull);
    });

    test('introspect returns null for unreachable endpoint', () async {
      final result = await GraphQLIntrospectionService.introspect(
        url: 'http://localhost:1/graphql',
      );
      expect(result, isNull);
    });

    test('parses fixture introspection response correctly', () {
      final jsonStr = _fixture('introspection_response.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final schema = GqlSchema.fromIntrospection(data);

      expect(schema.queryTypeName, equals('Query'));
      expect(schema.mutationTypeName, equals('Mutation'));
      expect(schema.subscriptionTypeName, isNull);

      // Should have the fixture types
      expect(schema.types.containsKey('Product'), isTrue);
      expect(schema.types.containsKey('ProductVariant'), isTrue);
      expect(schema.types.containsKey('ProductSortOrder'), isTrue);
      expect(schema.types.containsKey('ProductListOptions'), isTrue);
      expect(schema.types.containsKey('CreateProductInput'), isTrue);
    });

    test('entityTypes excludes built-ins and root types', () {
      final jsonStr = _fixture('introspection_response.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final schema = GqlSchema.fromIntrospection(data);

      final entities = schema.entityTypes.toList();
      final entityNames = entities.map((e) => e.name).toList();

      expect(entityNames, contains('Product'));
      expect(entityNames, contains('ProductVariant'));
      expect(entityNames, isNot(contains('Query')));
      expect(entityNames, isNot(contains('Mutation')));
      expect(entityNames, isNot(contains('__Schema')));
      expect(entityNames, isNot(contains('__Type')));
    });

    test('enumTypes excludes built-ins', () {
      final jsonStr = _fixture('introspection_response.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final schema = GqlSchema.fromIntrospection(data);

      final enums = schema.enumTypes.toList();
      final enumNames = enums.map((e) => e.name).toList();

      expect(enumNames, contains('ProductSortOrder'));
      expect(enumNames, isNot(contains('__TypeKind')));
    });

    test('GqlTypeDef fields are parsed correctly', () {
      final jsonStr = _fixture('introspection_response.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final schema = GqlSchema.fromIntrospection(data);

      final product = schema.types['Product']!;
      expect(product.isObject, isTrue);
      expect(product.description, equals('A product in the catalog'));
      expect(product.fields, isNotNull);
      expect(product.fields!.length, equals(7));

      final idField = product.fields!.firstWhere((f) => f.name == 'id');
      expect(idField.type.isNonNull, isTrue);
      expect(idField.type.namedType.name, equals('ID'));

      final variantsField = product.fields!.firstWhere(
        (f) => f.name == 'variants',
      );
      expect(variantsField.type.isList, isTrue);
      expect(
        variantsField.type.listElementType?.namedType.name,
        equals('ProductVariant'),
      );
    });

    test('enum values are parsed correctly', () {
      final jsonStr = _fixture('introspection_response.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final schema = GqlSchema.fromIntrospection(data);

      final sortOrder = schema.types['ProductSortOrder']!;
      expect(sortOrder.isEnum, isTrue);
      expect(sortOrder.enumValues, isNotNull);
      expect(sortOrder.enumValues!.length, equals(6));
      expect(
        sortOrder.enumValues!.map((e) => e.name).toList(),
        containsAll(['NAME_ASC', 'PRICE_DESC']),
      );
    });

    test('input object fields are parsed correctly', () {
      final jsonStr = _fixture('introspection_response.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final schema = GqlSchema.fromIntrospection(data);

      final createInput = schema.types['CreateProductInput']!;
      expect(createInput.isInputObject, isTrue);
      expect(createInput.inputFields, isNotNull);
      expect(createInput.inputFields!.length, equals(4));

      final nameField = createInput.inputFields!.firstWhere(
        (f) => f.name == 'name',
      );
      expect(nameField.type.isNonNull, isTrue);
    });
  });

  group('GraphqlSchemaTranslator', () {
    test('translates entity types from fixture schema', () {
      final jsonStr = _fixture('introspection_response.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final schema = GqlSchema.fromIntrospection(data);

      final translator = GraphQLSchemaTranslator(schema);
      final entities = translator.extractEntitySpecs();
      final entityNames = entities.map((e) => e.name).toList();

      expect(entityNames, contains('Product'));
      expect(entityNames, contains('ProductVariant'));

      // Product should have an ID field
      final product = entities.firstWhere((e) => e.name == 'Product');
      expect(product.idField, equals('id'));
      expect(product.fields.length, equals(7));
    });

    test('translates enum types from fixture schema', () {
      final jsonStr = _fixture('introspection_response.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final schema = GqlSchema.fromIntrospection(data);

      final translator = GraphQLSchemaTranslator(schema);
      final enums = translator.extractEnumSpecs();
      final enumNames = enums.map((e) => e.name).toList();

      expect(enumNames, contains('ProductSortOrder'));
      expect(enumNames, isNot(contains('__TypeKind')));

      final sortOrder = enums.firstWhere((e) => e.name == 'ProductSortOrder');
      expect(sortOrder.values.length, equals(6));
    });

    test('translates query and mutation operations', () {
      final jsonStr = _fixture('introspection_response.json');
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final schema = GqlSchema.fromIntrospection(data);

      final translator = GraphQLSchemaTranslator(schema);
      final operations = translator.extractOperationSpecs();

      expect(operations.isNotEmpty, isTrue);

      final opNames = operations.map((o) => o.name).toList();
      expect(opNames, contains('products'));
      expect(opNames, contains('product'));
      expect(opNames, contains('createProduct'));
    });
  });
}
