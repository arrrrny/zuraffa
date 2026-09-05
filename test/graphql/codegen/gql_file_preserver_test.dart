import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('GqlFilePreserver', () {
    late Directory tempDir;
    late GqlFilePreserver preserver;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('gql_preserver_');
      preserver = GqlFilePreserver(schema: _testSchema());
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('generates new file when missing', () {
      final path = '${tempDir.path}/get_product.graphql';
      final action = preserver.decide(
        path,
        'query GetProduct { product { id } }',
      );
      expect(action, PreserverAction.generate);
    });

    test('preserves valid existing file', () {
      final path = '${tempDir.path}/get_product.graphql';
      File(path).writeAsStringSync('query GetProduct { product { id } }');

      final action = preserver.decide(path, 'different content');
      expect(action, PreserverAction.preserve);
    });

    test('overwrites invalid existing file', () {
      final path = '${tempDir.path}/get_product.graphql';
      File(path).writeAsStringSync('query GetProduct { nonExistent { id } }');

      final action = preserver.decide(
        path,
        'query GetProduct { product { id } }',
      );
      expect(action, PreserverAction.overwrite);
    });

    test('force always overwrites', () {
      final path = '${tempDir.path}/get_product.graphql';
      File(path).writeAsStringSync('query GetProduct { product { id } }');

      final action = preserver.decide(path, 'different', force: true);
      expect(action, PreserverAction.overwrite);
    });

    test('overwrites UNVALIDATED files', () {
      final path = '${tempDir.path}/get_product.graphql';
      File(
        path,
      ).writeAsStringSync('# UNVALIDATED\nquery GetProduct { product { id } }');

      final action = preserver.decide(
        path,
        'query GetProduct { product { id } }',
      );
      expect(action, PreserverAction.overwrite);
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
            args: [],
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
        ],
      ),
      'ID': GraphQLScalarType(name: 'ID'),
    },
    queryTypeName: 'Query',
  );
}
