import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/mcp_tool.dart';
import 'package:zuraffa/src/core/module/mcp_tool_registry.dart';
import 'package:zuraffa/src/mcp/streamable_http_server.dart';

class _EchoTool implements McpTool {
  @override
  String get name => 'echo';

  @override
  String get description => 'Echoes its argument.';

  @override
  Map<String, dynamic> get inputSchema => const {
    'type': 'object',
    'properties': {
      'msg': {'type': 'string'},
    },
  };

  @override
  Future<McpToolResult> call(Map<String, dynamic> arguments) async =>
      McpToolResult.ok(arguments['msg'] as String? ?? '');
}

void main() {
  final registry = McpToolRegistry()..register(_EchoTool());

  Future<McpStreamableHttpServer> startServer({
    String? token,
    Map<String, Set<String>>? allowlist,
    bool bindAll = false,
  }) async {
    final server = McpStreamableHttpServer(
      registry: registry,
      authToken: token,
      tokenToolAllowlist: allowlist,
      bindAll: bindAll,
    );
    await server.start(port: 0); // ephemeral port
    return server;
  }

  /// POSTs one JSON-RPC message and returns (status, headers, decoded body).
  Future<(int, HttpHeaders, dynamic)> post(
    int port,
    Map<String, dynamic> rpc, {
    String? token,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      request.headers.contentType = ContentType.json;
      if (token != null) {
        request.headers.set('Authorization', 'Bearer $token');
      }
      request.write(jsonEncode(rpc));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = body.isEmpty ? null : jsonDecode(body);
      return (response.statusCode, response.headers, decoded);
    } finally {
      client.close(force: true);
    }
  }

  group('McpStreamableHttpServer', () {
    test(
      'serves initialize, tools/list and tools/call over POST /mcp',
      () async {
        final server = await startServer();
        try {
          final (initStatus, _, initBody) = await post(server.port!, {
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'initialize',
            'params': {},
          });
          expect(initStatus, 200);
          expect(initBody['result']['protocolVersion'], '2024-11-05');
          expect(initBody['result']['serverInfo']['name'], 'zuraffa-app-mcp');

          final (_, _, listBody) = await post(server.port!, {
            'jsonrpc': '2.0',
            'id': 2,
            'method': 'tools/list',
          });
          final tools = listBody['result']['tools'] as List;
          expect(tools.map((t) => t['name']), contains('echo'));

          final (_, _, callBody) = await post(server.port!, {
            'jsonrpc': '2.0',
            'id': 3,
            'method': 'tools/call',
            'params': {
              'name': 'echo',
              'arguments': {'msg': 'hello'},
            },
          });
          final content = callBody['result']['content'] as List;
          expect(callBody['result']['isError'], isNot(true));
          expect(content.first['text'], 'hello');
        } finally {
          await server.stop();
        }
      },
    );

    test('requires the bearer token when one is configured', () async {
      final server = await startServer(token: 's3cret');
      try {
        final (noTokenStatus, noTokenHeaders, _) = await post(server.port!, {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'ping',
        });
        expect(noTokenStatus, 401);
        expect(noTokenHeaders.value('www-authenticate'), 'Bearer');

        final (_, _, wrongBody) = await post(server.port!, {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'ping',
        }, token: 'wrong');
        expect(wrongBody['error']['code'], -32001);

        final (okStatus, _, okBody) = await post(server.port!, {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'ping',
        }, token: 's3cret');
        expect(okStatus, 200);
        expect(okBody['result']['pong'], isTrue);
      } finally {
        await server.stop();
      }
    });

    test(
      'binds loopback by default and refuses bindAll without a token',
      () async {
        final server = await startServer();
        try {
          expect(server.isRunning, isTrue);
          expect(server.port, isNotNull);
        } finally {
          await server.stop();
        }
        expect(server.isRunning, isFalse);

        expect(
          () => McpStreamableHttpServer(
            registry: registry,
            bindAll: true, // no token — must be refused
          ).start(port: 0),
          throwsArgumentError,
        );
      },
    );

    test('GET /mcp is 405 (stateless server offers no GET stream)', () async {
      final server = await startServer();
      try {
        final client = HttpClient();
        try {
          final request = await client.getUrl(
            Uri.parse('http://127.0.0.1:${server.port}/mcp'),
          );
          final response = await request.close();
          expect(response.statusCode, 405);
          expect(response.headers.value('allow'), 'POST');
          await response.drain<void>();
        } finally {
          client.close(force: true);
        }
      } finally {
        await server.stop();
      }
    });

    test('notifications (no id) get 202 Accepted with no body', () async {
      final server = await startServer();
      try {
        final client = HttpClient();
        try {
          final request = await client.postUrl(
            Uri.parse('http://127.0.0.1:${server.port}/mcp'),
          );
          request.headers.contentType = ContentType.json;
          request.write(
            jsonEncode({
              'jsonrpc': '2.0',
              'method': 'notifications/initialized',
            }),
          );
          final response = await request.close();
          expect(response.statusCode, 202);
          final body = await response.transform(utf8.decoder).join();
          expect(body, isEmpty);
        } finally {
          client.close(force: true);
        }
      } finally {
        await server.stop();
      }
    });

    test(
      'disabled tools are hidden from tools/list and rejected on call',
      () async {
        final server = await startServer();
        final localRegistry = registry;
        try {
          localRegistry.disable('echo');
          final (_, _, listBody) = await post(server.port!, {
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'tools/list',
          });
          expect(
            (listBody['result']['tools'] as List).map((t) => t['name']),
            isNot(contains('echo')),
          );

          final (_, _, callBody) = await post(server.port!, {
            'jsonrpc': '2.0',
            'id': 2,
            'method': 'tools/call',
            'params': {'name': 'echo', 'arguments': {}},
          });
          expect(callBody['error']['code'], -32602);
        } finally {
          localRegistry.enable('echo');
          await server.stop();
        }
      },
    );

    test('per-token allowlist blocks unlisted tools with -32000', () async {
      final server = await startServer(
        token: 's3cret',
        allowlist: {
          's3cret': {'other'},
        },
      );
      try {
        final (_, _, body) = await post(server.port!, {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'tools/call',
          'params': {
            'name': 'echo',
            'arguments': {'msg': 'hi'},
          },
        }, token: 's3cret');
        expect(body['error']['code'], -32000);
        expect(body['error']['message'], contains('echo'));
      } finally {
        await server.stop();
      }
    });
  });
}
