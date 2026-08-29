import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/mcp_local_host.dart';
import 'package:zuraffa/src/core/module/mcp_tool.dart';
import 'package:zuraffa/src/core/module/mcp_tool_registry.dart';

class _AddTool implements McpTool {
  @override
  String get name => 'add';
  @override
  String get description => 'Adds two numbers.';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'a': {'type': 'number'},
      'b': {'type': 'number'},
    },
    'required': ['a', 'b'],
  };
  @override
  Future<McpToolResult> call(Map<String, dynamic> args) async =>
      McpToolResult.ok('${(args['a'] as num) + (args['b'] as num)}');
}

class _ThrowingTool implements McpTool {
  @override
  String get name => 'boom';
  @override
  String get description => 'Always throws.';
  @override
  Map<String, dynamic> get inputSchema => const {'type': 'object'};
  @override
  Future<McpToolResult> call(Map<String, dynamic> args) async =>
      throw StateError('nope');
}

void main() {
  group('McpToolRegistry.call (in-proc bridge, server half, #384 req #2)', () {
    late McpToolRegistry registry;
    setUp(() {
      registry = McpToolRegistry()..register(_AddTool());
    });

    test('invokes a registered tool and returns its result', () async {
      final r = await registry.call('add', {'a': 2, 'b': 3});
      expect(r.isError, isFalse);
      expect(r.text, '5');
    });

    test(
      'returns an error result for an unknown tool (never throws)',
      () async {
        final r = await registry.call('missing', {});
        expect(r.isError, isTrue);
        expect(r.text, contains('Unknown tool'));
      },
    );

    test('converts handler throws into tool-level error results', () async {
      registry.register(_ThrowingTool());
      final r = await registry.call('boom', {});
      expect(r.isError, isTrue);
    });
  });

  group('LocalMcpHost', () {
    late LocalMcpHost host;
    setUp(() => host = LocalMcpHost(McpToolRegistry()..register(_AddTool())));

    test('listTools mirrors the registry definitions', () {
      final tools = host.listTools();
      expect(tools.single['name'], 'add');
      expect(host.toolNames, ['add']);
    });

    test('callTool invokes the tool without any transport', () async {
      final r = await host.callTool('add', {'a': 1, 'b': 4});
      expect(r.text, '5');
    });
  });
}
