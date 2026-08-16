import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/mcp_stdio_server.dart';
import 'package:zuraffa/src/core/module/mcp_tool.dart';
import 'package:zuraffa/src/core/module/mcp_tool_registry.dart';

void main() {
  group('McpStdioServer', () {
    late McpToolRegistry registry;
    late StringBuffer output;
    late StringBuffer errors;

    setUp(() {
      registry = McpToolRegistry();
      output = StringBuffer();
      errors = StringBuffer();
    });

    Future<String> runSession(List<String> lines) async {
      final input = Stream<List<int>>.fromIterable(
        lines.map((l) => utf8.encode('$l\n')),
      );
      final server = McpStdioServer(
        registry: registry,
        inputStream: input,
        outputSink: output,
        errorSink: errors,
      );
      await server.run();
      return output.toString();
    }

    test('initialize returns protocolVersion 2024-11-05 + serverInfo', () async {
      registry.register(_EchoTool());
      final out = await runSession([
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
        }),
      ]);
      final resp = jsonDecode(out.trim()) as Map<String, dynamic>;
      expect(resp['jsonrpc'], '2.0');
      expect(resp['id'], 1);
      final result = resp['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], '2024-11-05');
      expect(
        (result['serverInfo'] as Map)['name'],
        'zuraffa-app-mcp',
      );
    });

    test('tools/list derives inputSchema from registered tools', () async {
      registry.register(_EchoTool());
      final out = await runSession([
        jsonEncode({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'}),
      ]);
      final resp = jsonDecode(out.trim()) as Map<String, dynamic>;
      final tools = (resp['result'] as Map)['tools'] as List;
      expect(tools.length, 1);
      final t = tools.single as Map<String, dynamic>;
      expect(t['name'], 'echo');
      expect(t['description'], contains('Echoes'));
      final schema = t['inputSchema'] as Map<String, dynamic>;
      expect(schema['type'], 'object');
      expect(schema['required'], ['message']);
    });

    test('tools/call dispatches to the named tool and returns its result', () async {
      registry.register(_EchoTool());
      final out = await runSession([
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 3,
          'method': 'tools/call',
          'params': {
            'name': 'echo',
            'arguments': {'message': 'hi'},
          },
        }),
      ]);
      final resp = jsonDecode(out.trim()) as Map<String, dynamic>;
      expect(resp['id'], 3);
      final result = resp['result'] as Map<String, dynamic>;
      final content = result['content'] as List;
      expect((content.single as Map)['text'], 'echo: hi');
      expect(result.containsKey('isError'), isFalse);
    });

    test('tools/call for an unknown tool returns -32602 error', () async {
      registry.register(_EchoTool());
      final out = await runSession([
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 4,
          'method': 'tools/call',
          'params': {'name': 'nope', 'arguments': {}},
        }),
      ]);
      final resp = jsonDecode(out.trim()) as Map<String, dynamic>;
      final err = resp['error'] as Map<String, dynamic>;
      expect(err['code'], -32602);
      expect(err['message'], contains('Unknown tool'));
    });

    test('tools/call with missing name returns -32602 error', () async {
      registry.register(_EchoTool());
      final out = await runSession([
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 5,
          'method': 'tools/call',
          'params': {'arguments': {}},
        }),
      ]);
      final resp = jsonDecode(out.trim()) as Map<String, dynamic>;
      final err = resp['error'] as Map<String, dynamic>;
      expect(err['code'], -32602);
    });

    test('tool that throws is surfaced as isError: true (not transport error)', () async {
      registry.register(_ThrowingTool());
      final out = await runSession([
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 6,
          'method': 'tools/call',
          'params': {'name': 'boom', 'arguments': {}},
        }),
      ]);
      final resp = jsonDecode(out.trim()) as Map<String, dynamic>;
      final result = resp['result'] as Map<String, dynamic>;
      expect(result['isError'], isTrue);
      expect(
        (result['content'] as List).single,
        isA<Map>()
            .having((m) => m['type'], 'type', 'text')
            .having((m) => m['text'], 'text', contains('boom')),
      );
    });

    test('ping returns { pong: true }', () async {
      final out = await runSession([
        jsonEncode({'jsonrpc': '2.0', 'id': 7, 'method': 'ping'}),
      ]);
      final resp = jsonDecode(out.trim()) as Map<String, dynamic>;
      expect((resp['result'] as Map)['pong'], isTrue);
    });

    test('unknown method returns -32601', () async {
      final out = await runSession([
        jsonEncode({'jsonrpc': '2.0', 'id': 8, 'method': 'no/such/method'}),
      ]);
      final resp = jsonDecode(out.trim()) as Map<String, dynamic>;
      expect((resp['error'] as Map)['code'], -32601);
    });

    test('notification (id=null) gets no response on stdout', () async {
      final out = await runSession([
        jsonEncode({'jsonrpc': '2.0', 'method': 'some/notification'}),
      ]);
      expect(out.trim(), isEmpty);
    });

    test('malformed JSON line returns -32700 parse error', () async {
      final out = await runSession(['{ not valid json']);
      final resp = jsonDecode(out.trim()) as Map<String, dynamic>;
      expect((resp['error'] as Map)['code'], -32700);
    });

    test('empty lines are silently skipped', () async {
      registry.register(_EchoTool());
      final out = await runSession([
        '',
        '   ',
        jsonEncode({'jsonrpc': '2.0', 'id': 9, 'method': 'ping'}),
      ]);
      final lines = out.trim().split('\n');
      expect(lines.length, 1);
      expect(jsonDecode(lines.single)['id'], 9);
    });

    test('multiple sequential requests get sequential responses', () async {
      registry.register(_EchoTool());
      final out = await runSession([
        jsonEncode({'jsonrpc': '2.0', 'id': 10, 'method': 'ping'}),
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 11,
          'method': 'tools/call',
          'params': {
            'name': 'echo',
            'arguments': {'message': 'one'},
          },
        }),
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 12,
          'method': 'tools/call',
          'params': {
            'name': 'echo',
            'arguments': {'message': 'two'},
          },
        }),
      ]);
      final responses = out
          .trim()
          .split('\n')
          .map((l) => jsonDecode(l) as Map<String, dynamic>)
          .toList();
      expect(responses.length, 3);
      expect(responses[0]['id'], 10);
      expect(responses[1]['id'], 11);
      expect(responses[2]['id'], 12);
      expect(
        ((responses[1]['result'] as Map)['content'] as List).single,
        isA<Map>().having((m) => m['text'], 'text', 'echo: one'),
      );
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

class _ThrowingTool implements McpTool {
  @override
  String get name => 'boom';
  @override
  String get description => 'Always throws.';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {},
  };
  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    throw StateError('boom');
  }
}
