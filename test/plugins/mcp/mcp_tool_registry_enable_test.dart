import 'package:test/test.dart';
import 'package:zuraffa/src/core/cancel_token.dart';
import 'package:zuraffa/src/core/module/mcp_dispatcher.dart';
import 'package:zuraffa/src/core/module/mcp_tool.dart';
import 'package:zuraffa/src/core/module/mcp_tool_registry.dart';
import 'package:zuraffa/src/core/module/mcp_usecase_tool.dart';
import 'package:zuraffa/src/domain/usecase.dart';

class _EchoTool implements McpTool {
  @override
  String get name => 'echo';

  @override
  String get description => 'Echoes its argument.';

  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {},
  };

  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async =>
      McpToolResult.ok(arguments['msg'] as String? ?? '');
}

class _ReadonlyGreetTool extends McpUseCaseTool<String, Map<String, dynamic>> {
  _ReadonlyGreetTool()
    : super(
        useCase: _GreetUseCase(),
        name: 'greet',
        description: 'Readonly greeting.',
        readonly: true,
        decode: (args) => args,
      );
}

class _GreetUseCase extends UseCase<String, Map<String, dynamic>> {
  @override
  Future<String> execute(
    Map<String, dynamic> params,
    CancelToken? cancelToken,
  ) async => 'hi ${params['name']}';
}

void main() {
  group('McpToolRegistry per-tool enable/disable', () {
    test(
      'disable excludes the tool from toolDefinitions and rejects calls',
      () async {
        final registry = McpToolRegistry()..register(_EchoTool());
        registry.disable('echo');
        expect(registry.isEnabled('echo'), isFalse);
        expect(registry.toolNames, isEmpty); // hidden, not removed
        expect(registry.find('echo'), isNotNull); // still registered
        expect(
          registry.toolDefinitions().any((t) => t['name'] == 'echo'),
          isFalse,
        );
        final result = await registry.call('echo', {'msg': 'hi'});
        expect(result.isError, isTrue);
        expect(result.text, contains('disabled'));
      },
    );

    test('enable restores a disabled tool', () async {
      final registry = McpToolRegistry()..register(_EchoTool());
      registry.disable('echo');
      registry.enable('echo');
      expect(registry.isEnabled('echo'), isTrue);
      expect(
        registry.toolDefinitions().any((t) => t['name'] == 'echo'),
        isTrue,
      );
      final result = await registry.call('echo', {'msg': 'hi'});
      expect(result.isError, isFalse);
      expect(result.text, 'hi');
    });

    test('isEnabled is false for unknown tools', () {
      final registry = McpToolRegistry();
      expect(registry.isEnabled('nope'), isFalse);
    });

    test('toolDefinitions emits Vendure-style annotations for '
        'readonly-aware tools only', () {
      final registry = McpToolRegistry()
        ..register(_EchoTool())
        ..register(_ReadonlyGreetTool());
      final defs = {
        for (final d in registry.toolDefinitions()) d['name'] as String: d,
      };
      // Plain McpTool: no annotations key (classification unknown).
      expect(defs['echo']!.containsKey('annotations'), isFalse);
      // Readonly-aware registration: explicit hints.
      final annotations = defs['greet']!['annotations'] as Map<String, dynamic>;
      expect(annotations['readOnlyHint'], isTrue);
      expect(annotations['destructiveHint'], isFalse);
    });

    test('mutating-aware tools advertise destructiveHint', () {
      final registry = McpToolRegistry()
        ..register(
          McpUseCaseTool<String, Map<String, dynamic>>(
            useCase: _GreetUseCase(),
            name: 'mutate',
            description: 'Mutating (readonly defaults to false).',
            decode: (args) => args,
          ),
        );
      final annotations =
          registry.toolDefinitions().single['annotations']
              as Map<String, dynamic>;
      expect(annotations['readOnlyHint'], isFalse);
      expect(annotations['destructiveHint'], isTrue);
    });
  });

  group('McpDispatcher × disabled tools', () {
    test('tools/call on a disabled tool is a -32602 JSON-RPC error', () async {
      final registry = McpToolRegistry()..register(_EchoTool());
      final dispatcher = McpDispatcher(registry: registry);
      registry.disable('echo');
      final response = await dispatcher.dispatch({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/call',
        'params': {
          'name': 'echo',
          'arguments': {'msg': 'hi'},
        },
      });
      expect((response!['error'] as Map<String, dynamic>)['code'], -32602);
    });

    test('tools/list hides disabled tools over the wire', () async {
      final registry = McpToolRegistry()..register(_EchoTool());
      final dispatcher = McpDispatcher(registry: registry);
      registry.disable('echo');
      final response = await dispatcher.dispatch({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/list',
      });
      expect((response!['result'] as Map<String, dynamic>)['tools'], isEmpty);
    });
  });
}
