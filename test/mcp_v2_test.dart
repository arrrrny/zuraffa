import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:zuraffa/src/mcp/auth.dart';
import 'package:zuraffa/src/mcp/capabilities/arch_capability.dart';
import 'package:zuraffa/src/mcp/session_store.dart';
import 'package:zuraffa/src/mcp/v2_tools.dart';

void main() {
  group('McpAuth', () {
    test('allows all connections when no token is set', () {
      final auth = McpAuth();
      expect(auth.isEnabled, false);
    });

    test('generates a token', () {
      final token = McpAuth.generateToken();
      expect(token.length, 32);
      expect(token, isNot(equals(McpAuth.generateToken())));
    });

    test('validates correct token', () {
      final auth = McpAuth(token: 'test-token-123');
      expect(auth.isEnabled, true);
      expect(auth.validateHeader('Bearer test-token-123'), true);
      expect(auth.validateHeader('Bearer wrong'), false);
      expect(auth.validateHeader(null), false);
    });

    test('validates message auth', () {
      final auth = McpAuth(token: 'my-secret');
      expect(auth.validateMessage({}, '192.168.1.1'), isNot(null));
      expect(
        auth.validateMessage({'auth': 'wrong'}, '192.168.1.1'),
        isNot(null),
      );
      expect(auth.validateMessage({'auth': 'my-secret'}, '192.168.1.1'), null);
      expect(auth.validateMessage({}, '127.0.0.1'), null);
      expect(auth.validateMessage({}, '::1'), null);
    });
  });

  group('ArchitectureModel', () {
    test('serializes empty model to JSON', () {
      const model = ArchitectureModel(projectRoot: '/test');
      final json = model.toJson();
      expect(json['projectRoot'], '/test');
      expect(json['entities'], []);
      expect(json['stats']['entityCount'], 0);
    });

    test('serializes model with entities and usecases', () {
      final model = ArchitectureModel(
        projectRoot: '/test',
        entities: [
          ArchEntity(
            name: 'Product',
            path: 'lib/src/domain/entities/product/product.dart',
            fields: [
              ArchField(name: 'title', type: 'String'),
              ArchField(name: 'price', type: 'double', isNullable: true),
            ],
            hasJson: true,
          ),
        ],
        useCases: [
          ArchUseCase(
            name: 'GetProductUseCase',
            path: 'lib/src/domain/usecases/product/get_product.dart',
            entity: 'Product',
            returnType: 'Product',
            paramsType: 'String',
          ),
        ],
      );

      final json = model.toJson();
      expect(json['entities'].length, 1);
      expect(json['entities'][0]['name'], 'Product');
      expect(json['entities'][0]['fields'][1]['nullable'], true);
      expect(json['useCases'].length, 1);
      expect(json['useCases'][0]['returns'], 'Product');
      expect(json['stats']['entityCount'], 1);
      expect(json['stats']['useCaseCount'], 1);
    });
  });

  group('v2ToolDefinitions', () {
    test('returns all 11 v2 tool definitions', () {
      final tools = v2ToolDefinitions();
      expect(tools.length, 11);

      final names = tools.map((t) => t['name'] as String).toList();
      expect(names, contains('arch_inspect'));
      expect(names, contains('arch_refactor'));
      expect(names, contains('test_runUseCase'));
      expect(names, contains('code_generateView'));
      expect(names, contains('graphql_pullSchema'));
      expect(names, contains('graphql_generateFromSchema'));
      expect(names, contains('xray_inspect'));
      expect(names, contains('xray_triggerAction'));
      expect(names, contains('xray_triggerMock'));
      expect(names, contains('session_save'));
      expect(names, contains('session_restore'));
    });

    test('each tool has required inputSchema', () {
      final tools = v2ToolDefinitions();
      for (final tool in tools) {
        expect(
          tool.containsKey('inputSchema'),
          true,
          reason: '${tool['name']} missing inputSchema',
        );
        final schema = tool['inputSchema'] as Map<String, dynamic>;
        expect(schema['type'], 'object');
      }
    });

    test('arch_refactor has correct required and enum values', () {
      final tools = v2ToolDefinitions();
      final refactor = tools.firstWhere((t) => t['name'] == 'arch_refactor');
      final schema = refactor['inputSchema'] as Map<String, dynamic>;
      final required = schema['required'] as List;
      expect(required, contains('operation'));
      expect(required, contains('entity'));
      final opEnum = (schema['properties']['operation'] as Map)['enum'] as List;
      expect(opEnum, ['rename-entity-field', 'add-entity-method']);
    });
  });

  group('ArchInspector', () {
    late Directory tempDir;
    late ArchInspector inspector;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mcp_test_');
      inspector = ArchInspector(projectRoot: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('inspect returns empty model for empty project', () async {
      final model = await inspector.inspect();
      expect(model.entities, isEmpty);
      expect(model.useCases, isEmpty);
      expect(model.repositories, isEmpty);
    });

    test('inspect finds entities in standard layout', () async {
      final entityDir = Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'entities', 'product'),
      );
      await entityDir.create(recursive: true);
      await File(p.join(entityDir.path, 'product.dart')).writeAsString(
        r'class $Product {'
        '\n  final String title;\n  final double? price;\n}\n',
      );

      final model = await inspector.inspect();
      expect(model.entities.length, 1);
      expect(model.entities[0].name, 'Product');
      expect(model.entities[0].fields.length, 2);
      expect(model.entities[0].fields[0].name, 'title');
      expect(model.entities[0].fields[1].isNullable, true);
    });
  });

  group('McpSessionStore', () {
    late Directory tempDir;
    late McpSessionStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mcp_session_test_');
      store = McpSessionStore(projectRoot: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates and retrieves a session', () async {
      final session = await store.getOrCreate('test-1');
      expect(session.id, 'test-1');
      expect(session.state, isEmpty);

      final retrieved = await store.getOrCreate('test-1');
      expect(retrieved.id, 'test-1');
    });

    test('saves and lists sessions', () async {
      final session = await store.getOrCreate('test-2');
      session.state['key'] = 'value';
      await store.save(session);

      final sessions = await store.listSessions();
      expect(sessions, contains('test-2'));
    });

    test('deletes a session', () async {
      await store.getOrCreate('test-3');
      await store.save(await store.getOrCreate('test-3'));
      await store.delete('test-3');

      final sessions = await store.listSessions();
      expect(sessions, isNot(contains('test-3')));
    });
  });
}
