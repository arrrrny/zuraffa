import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/mcp_tool.dart';
import 'package:zuraffa/src/core/module/mcp_tool_registry.dart';

void main() {
  group('McpToolRegistry', () {
    late McpToolRegistry registry;

    setUp(() {
      registry = McpToolRegistry();
    });

    test('starts empty', () {
      expect(registry.isEmpty, isTrue);
      expect(registry.length, 0);
      expect(registry.allTools, isEmpty);
      expect(registry.toolDefinitions(), isEmpty);
    });

    test('register() adds a tool findable by name', () {
      registry.register(_EchoTool());
      expect(registry.length, 1);
      expect(registry.find('echo'), isNotNull);
      expect(registry.find('echo')?.name, 'echo');
    });

    test('register() preserves insertion order in allTools', () {
      registry.register(_EchoTool());
      registry.register(_ReverseTool());
      registry.register(_PingTool());
      expect(registry.toolNames, ['echo', 'reverse', 'ping']);
    });

    test('register() throws on duplicate name (override=false)', () {
      registry.register(_EchoTool());
      expect(
        () => registry.register(_EchoTool()),
        throwsA(isA<StateError>()),
      );
    });

    test('register(override: true) replaces existing tool', () {
      registry.register(_EchoTool());
      registry.register(_OtherEchoTool(), override: true);
      expect(registry.length, 1);
      expect(registry.find('echo')?.description, contains('other'));
    });

    test('unregister() removes the tool and returns it', () {
      registry.register(_EchoTool());
      final removed = registry.unregister('echo');
      expect(removed?.name, 'echo');
      expect(registry.length, 0);
      expect(registry.find('echo'), isNull);
    });

    test('unregister() returns null for unknown name', () {
      expect(registry.unregister('nope'), isNull);
    });

    test('clear() empties the registry', () {
      registry.register(_EchoTool());
      registry.register(_PingTool());
      registry.clear();
      expect(registry.isEmpty, isTrue);
    });

    group('toolDefinitions()', () {
      test('returns the MCP tools/list shape', () {
        registry.register(_EchoTool());
        registry.register(_PingTool());

        final defs = registry.toolDefinitions();
        expect(defs.length, 2);

        final echo = defs.firstWhere((d) => d['name'] == 'echo');
        expect(echo['description'], 'Echoes the message argument.');
        expect(echo['inputSchema'], isA<Map<String, dynamic>>());
        expect((echo['inputSchema'] as Map)['type'], 'object');
      });

      test('derives inputSchema from each tool', () {
        registry.register(_PingTool());
        final defs = registry.toolDefinitions();
        final ping = defs.single;
        final schema = ping['inputSchema'] as Map<String, dynamic>;
        expect(schema['properties'], isA<Map>());
        expect((schema['properties'] as Map)['url'], isNotNull);
        expect(schema['required'], ['url']);
      });
    });
  });

  group('McpToolResult', () {
    test('.ok constructs a success result with text content', () {
      final r = McpToolResult.ok('hello');
      expect(r.isError, isFalse);
      expect(r.text, 'hello');
    });

    test('.error constructs an error result', () {
      final r = McpToolResult.error('boom');
      expect(r.isError, isTrue);
      expect(r.text, 'boom');
    });

    test('.toJson emits the MCP tools/call result shape', () {
      final r = McpToolResult.ok('hello', data: {'k': 1});
      final json = r.toJson();
      expect(json.containsKey('isError'), isFalse);
      expect(json['content'], [
        {'type': 'text', 'text': 'hello'},
      ]);
      expect(json['data'], {'k': 1});
    });

    test('.toJson on an error includes isError: true', () {
      final r = McpToolResult.error('boom');
      expect(r.toJson()['isError'], isTrue);
    });
  });
}

class _EchoTool implements McpTool {
  @override
  String get name => 'echo';
  @override
  String get description => 'Echoes the message argument.';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'message': {'type': 'string'},
    },
    'required': ['message'],
  };
  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    final msg = arguments['message'] as String? ?? '';
    return McpToolResult.ok('echo: $msg');
  }
}

class _OtherEchoTool implements McpTool {
  @override
  String get name => 'echo';
  @override
  String get description => 'The other echo (for override test).';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'message': {'type': 'string'},
    },
    'required': ['message'],
  };
  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    return McpToolResult.ok('other');
  }
}

class _ReverseTool implements McpTool {
  @override
  String get name => 'reverse';
  @override
  String get description => 'Reverses the message argument.';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'message': {'type': 'string'},
    },
    'required': ['message'],
  };
  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    final msg = arguments['message'] as String? ?? '';
    return McpToolResult.ok(msg.split('').reversed.join());
  }
}

class _PingTool implements McpTool {
  @override
  String get name => 'ping';
  @override
  String get description => 'Pings a URL.';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'url': {'type': 'string'},
    },
    'required': ['url'],
  };
  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    return McpToolResult.ok('pong ${arguments['url']}');
  }
}
