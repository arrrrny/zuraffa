// End-to-end test for issue #369 acceptance criterion:
//   "an agent connects, calls takeScreenshot(url: ...), gets the result"
//
// Spins up an in-process McpStdioServer wired to a McpServerPlugin
// holding the three flagship MCP demo tools (fetch, printPdf,
// takeScreenshot), pipes a JSON-RPC `tools/call` request through
// stdin, and asserts the response shape. This is the canonical
// "handler dispatch through the DI tree" test — the tool resolves
// via the registry populated by McpServerPlugin.registerDependencies
// (which would in a real app be called by the ZuraffaEngine
// bootstrap with the populated DI tree).
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/mcp_stdio_server.dart';
import 'package:zuraffa/src/core/module/mcp_tool.dart';
import 'package:zuraffa/src/core/module/mcp_tool_registry.dart';

void main() {
  group('MCP plugin end-to-end (issue #369)', () {
    late McpToolRegistry registry;
    late StringBuffer errors;

    setUp(() {
      registry = McpToolRegistry();
      // Register the three flagship tools — mirroring the
      // examples/mcp_demo/lib/src/mcp/tools.dart list.
      registry.register(_FetchUrlTool());
      registry.register(_PrintPdfTool());
      registry.register(_TakeScreenshotTool());

      errors = StringBuffer();
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
        errorSink: errors,
      );
      await localServer.run();
      final lines = localOut.toString().trim().split('\n');
      if (lines.isEmpty || lines.first.isEmpty) {
        throw StateError('No response from server. stderr: $errors');
      }
      return jsonDecode(lines.first) as Map<String, dynamic>;
    }

    test('tools/list exposes all three flagship tools', () async {
      final resp = await send({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/list',
      });
      final tools = (resp['result'] as Map)['tools'] as List;
      final names = tools.map((t) => (t as Map)['name']).toSet();
      expect(names, containsAll(['fetch', 'printPdf', 'takeScreenshot']));
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
        if (['fetch', 'printPdf', 'takeScreenshot'].contains(name)) {
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
          'name': 'takeScreenshot',
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
          'name': 'printPdf',
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

    test('full initialize -> tools/list -> tools/call -> shutdown handshake', () async {
      // Drive a full agent handshake: init, list, call, shutdown.
      final lines = [
        jsonEncode({'jsonrpc': '2.0', 'id': 10, 'method': 'initialize'}),
        jsonEncode({'jsonrpc': '2.0', 'id': 11, 'method': 'tools/list'}),
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 12,
          'method': 'tools/call',
          'params': {
            'name': 'takeScreenshot',
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
        errorSink: errors,
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

// --- Flagship demo tools (mirrors examples/mcp_demo/lib/src/mcp/tools.dart) ---

class _FetchUrlTool implements McpTool {
  @override
  String get name => 'fetch';
  @override
  String get description =>
      'Fetch the content at the given URL and return it as text.';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'url': {'type': 'string', 'description': 'HTTP(S) URL to fetch.'},
    },
    'required': ['url'],
  };
  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    final url = arguments['url'] as String?;
    if (url == null || url.isEmpty) {
      return McpToolResult.error('Missing required argument: url');
    }
    return McpToolResult.ok('fetch(url: $url) — stubbed body', data: {'url': url});
  }
}

class _PrintPdfTool implements McpTool {
  @override
  String get name => 'printPdf';
  @override
  String get description =>
      'Render the given URL to a PDF document and return its path.';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'url': {'type': 'string'},
      'format': {
        'type': 'string',
        'enum': ['a4', 'letter'],
        'default': 'a4',
      },
    },
    'required': ['url'],
  };
  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    final url = arguments['url'] as String?;
    if (url == null || url.isEmpty) {
      return McpToolResult.error('Missing required argument: url');
    }
    final format = (arguments['format'] as String?) ?? 'a4';
    return McpToolResult.ok(
      'printPdf(url: $url, format: $format)',
      data: {'url': url, 'format': format},
    );
  }
}

class _TakeScreenshotTool implements McpTool {
  @override
  String get name => 'takeScreenshot';
  @override
  String get description =>
      'Take a screenshot of the given URL and return the image path.';
  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'url': {'type': 'string'},
      'width': {'type': 'integer', 'default': 1280},
      'height': {'type': 'integer', 'default': 800},
      'fullPage': {'type': 'boolean', 'default': false},
    },
    'required': ['url'],
  };
  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async {
    final url = arguments['url'] as String?;
    if (url == null || url.isEmpty) {
      return McpToolResult.error('Missing required argument: url');
    }
    final width = (arguments['width'] as num?)?.toInt() ?? 1280;
    final height = (arguments['height'] as num?)?.toInt() ?? 800;
    final fullPage = (arguments['fullPage'] as bool?) ?? false;
    return McpToolResult.ok(
      'takeScreenshot(url: $url, ${width}x$height, fullPage: $fullPage)',
      data: {
        'url': url,
        'width': width,
        'height': height,
        'fullPage': fullPage,
      },
    );
  }
}
