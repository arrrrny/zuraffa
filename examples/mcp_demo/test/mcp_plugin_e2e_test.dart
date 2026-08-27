// End-to-end test for issue #369 acceptance criterion:
//   "an agent connects, calls takeScreenshot(url: ...), gets the result"
//
// Exercises the REAL demo registration path: `mcpTools` from
// lib/src/mcp/tools.dart are registered via McpServerPlugin
// (registerDependencies) and bootstrapped through ZuraffaEngine's
// dependency-injection path. The stdio server then dispatches
// JSON-RPC requests against the live registry resolved from DI —
// so a broken demo tool list, plugin registration, or DI wiring
// fails this test.
import 'dart:async';
import 'dart:convert';

import 'package:mcp_demo/src/mcp/tools.dart';
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('MCP plugin end-to-end (issue #369, demo registration path)', () {
    late McpServerPlugin mcp;
    late McpToolRegistry registry;

    setUp(() async {
      final engine = ZuraffaEngine()
        ..register(McpServerPlugin(tools: mcpTools));
      await engine.bootstrap();
      mcp = engine['mcp'] as McpServerPlugin;
      registry = mcp.registry;
    });

    Future<Map<String, dynamic>> send(Map<String, dynamic> req) async {
      final input = Stream<List<int>>.fromIterable([
        utf8.encode('${jsonEncode(req)}\n'),
      ]);
      final localOut = StringBuffer();
      final localServer = McpStdioServer(
        registry: registry,
        inputStream: input,
        outputSink: localOut,
      );
      await localServer.run();
      final lines = localOut.toString().trim().split('\n');
      if (lines.isEmpty || lines.first.isEmpty) {
        throw StateError('No response from server.');
      }
      return jsonDecode(lines.first) as Map<String, dynamic>;
    }

    test('plugin registers the three flagship demo tools', () {
      final names = mcp.listTools().map((t) => t.name).toSet();
      expect(
        names,
        containsAll(['fetch', 'print_pdf', 'take_screenshot']),
      );
    });

    test('tools/list exposes all three flagship tools', () async {
      final resp = await send({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/list',
      });
      final tools = (resp['result'] as Map)['tools'] as List;
      final names = tools.map((t) => (t as Map)['name']).toSet();
      expect(names, containsAll(['fetch', 'print_pdf', 'take_screenshot']));
    });

    test('each flagship tool takes a `url` parameter (required)', () async {
      final resp = await send({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      });
      final tools = (resp['result'] as Map)['tools'] as List;
      for (final t in tools) {
        final name = (t as Map)['name'] as String;
        if (['fetch', 'print_pdf', 'take_screenshot'].contains(name)) {
          final schema = t['inputSchema'] as Map<String, dynamic>;
          final props = schema['properties'] as Map<String, dynamic>;
          final urlProp = props['url'] as Map<String, dynamic>;
          expect(urlProp['type'], 'string');
          expect(schema['required'], contains('url'));
        }
      }
    });

    test('agent calls takeScreenshot(url: ...) and gets the result', () async {
      final resp = await send({
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': {
          'name': 'take_screenshot',
          'arguments': {
            'url': 'https://example.com',
            'width': 1920,
            'height': 1080,
            'fullPage': true,
          },
        },
      });
      expect(resp['id'], 3);
      final result = resp['result'] as Map<String, dynamic>;
      expect(result.containsKey('isError'), isFalse);
      final content = result['content'] as List;
      expect((content.single as Map)['type'], 'text');
      final text = (content.single as Map)['text'] as String;
      expect(text, contains('https://example.com'));
      expect(text, contains('1920x1080'));
      expect(text, contains('fullPage'));
    });

    test('agent calls fetch(url: ...) and gets the result', () async {
      final resp = await send({
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'tools/call',
        'params': {
          'name': 'fetch',
          'arguments': {'url': 'https://example.com/data.json'},
        },
      });
      final result = resp['result'] as Map<String, dynamic>;
      final content = result['content'] as List;
      final text = (content.single as Map)['text'] as String;
      expect(text, contains('https://example.com/data.json'));
      expect(text, contains('fetch'));
    });

    test('agent calls printPdf(url: ...) with format option', () async {
      final resp = await send({
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'tools/call',
        'params': {
          'name': 'print_pdf',
          'arguments': {
            'url': 'https://example.com/report',
            'format': 'letter',
          },
        },
      });
      final result = resp['result'] as Map<String, dynamic>;
      final content = result['content'] as List;
      final text = (content.single as Map)['text'] as String;
      expect(text, contains('https://example.com/report'));
      expect(text, contains('letter'));
    });

    test('missing url argument surfaces as a tool-level error', () async {
      final resp = await send({
        'jsonrpc': '2.0',
        'id': 6,
        'method': 'tools/call',
        'params': {
          'name': 'fetch',
          'arguments': {},
        },
      });
      final result = resp['result'] as Map<String, dynamic>;
      expect(result['isError'], isTrue);
    });

    test('unknown tool name surfaces as JSON-RPC -32602 error', () async {
      final resp = await send({
        'jsonrpc': '2.0',
        'id': 7,
        'method': 'tools/call',
        'params': {'name': 'noSuchTool', 'arguments': {}},
      });
      final err = resp['error'] as Map<String, dynamic>;
      expect(err['code'], -32602);
    });

    test('full initialize -> tools/list -> tools/call -> shutdown handshake',
        () async {
      // Drive a full agent handshake: init, list, call, shutdown.
      final lines = [
        jsonEncode({'jsonrpc': '2.0', 'id': 10, 'method': 'initialize'}),
        jsonEncode({'jsonrpc': '2.0', 'id': 11, 'method': 'tools/list'}),
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 12,
          'method': 'tools/call',
          'params': {
            'name': 'take_screenshot',
            'arguments': {'url': 'https://example.com'},
          },
        }),
        jsonEncode({'jsonrpc': '2.0', 'id': 13, 'method': 'shutdown'}),
      ];
      final input = Stream<List<int>>.fromIterable(
        lines.map((l) => utf8.encode('$l\n')),
      );
      final localOut = StringBuffer();
      final localServer = McpStdioServer(
        registry: registry,
        inputStream: input,
        outputSink: localOut,
      );
      await localServer.run();
      final responses = localOut
          .toString()
          .trim()
          .split('\n')
          .map((l) => jsonDecode(l) as Map<String, dynamic>)
          .toList();

      expect(responses.length, 4);
      // initialize
      expect((responses[0]['result'] as Map)['protocolVersion'], '2024-11-05');
      // tools/list — 3 tools
      final tools = (responses[1]['result'] as Map)['tools'] as List;
      expect(tools.length, 3);
      // tools/call — takeScreenshot result
      final callResult = responses[2]['result'] as Map<String, dynamic>;
      expect(callResult.containsKey('isError'), isFalse);
      // shutdown
      expect(responses[3]['result'], {});
    });
  });
}
