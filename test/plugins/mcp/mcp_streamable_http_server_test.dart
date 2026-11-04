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

/// Reads a raw-socket HTTP response with a hard cap — a keep-alive
/// server never EOFs its socket, so the read must self-bound instead
/// of hanging on a connection the server keeps open.
Future<String> readResponse(Socket socket) => utf8.decoder
    .bind(socket)
    .timeout(const Duration(seconds: 5), onTimeout: (sink) => sink.close())
    .join();

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
          // listChanged is declared false honestly: no transport here
          // can push notifications/tools/list_changed (issue #2046).
          expect(
            initBody['result']['capabilities']['tools']['listChanged'],
            isFalse,
          );

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

    test('an allowlist-denied notification gets 202 with no body', () async {
      // JSON-RPC forbids a response object for an id-less message: the
      // denial must not echo `"id": null` back as an error body.
      final server = await startServer(
        token: 's3cret',
        allowlist: {
          's3cret': {'other'},
        },
      );
      try {
        final (status, _, body) = await post(server.port!, {
          'jsonrpc': '2.0',
          'method': 'tools/call',
          'params': {
            'name': 'echo',
            'arguments': {'msg': 'hi'},
          },
        }, token: 's3cret');
        expect(status, 202);
        expect(body, isNull);
      } finally {
        await server.stop();
      }
    });

    test(
      'rejects a non-JSON content-type (cross-origin no-cors defense)',
      () async {
        final server = await startServer();
        try {
          final client = HttpClient();
          try {
            // A simple cross-origin POST can only carry CORS-safelisted
            // types (text/plain) — exactly the shape that skips preflight.
            final request = await client.postUrl(
              Uri.parse('http://127.0.0.1:${server.port}/mcp'),
            );
            request.headers.contentType = ContentType.text;
            request.write(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': 1,
                'method': 'tools/call',
                'params': {
                  'name': 'echo',
                  'arguments': {'msg': 'pwned'},
                },
              }),
            );
            final response = await request.close();
            expect(response.statusCode, 403);
            await response.drain<void>();
          } finally {
            client.close(force: true);
          }
        } finally {
          await server.stop();
        }
      },
    );

    test('rejects a non-loopback Origin in unauthenticated mode', () async {
      final server = await startServer();
      try {
        final client = HttpClient();
        try {
          final request = await client.postUrl(
            Uri.parse('http://127.0.0.1:${server.port}/mcp'),
          );
          request.headers.contentType = ContentType.json;
          request.headers.set('Origin', 'https://evil.example');
          request.write(
            jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}),
          );
          final response = await request.close();
          expect(response.statusCode, 403);
          await response.drain<void>();
        } finally {
          client.close(force: true);
        }
      } finally {
        await server.stop();
      }
    });

    test(
      'rejects a non-loopback Host in unauthenticated mode (DNS rebinding)',
      () async {
        final server = await startServer();
        try {
          final socket = await Socket.connect('127.0.0.1', server.port!);
          try {
            socket.write(
              'POST /mcp HTTP/1.1\r\n'
              'Host: evil.example\r\n'
              'Content-Type: application/json\r\n'
              '\r\n'
              '{"jsonrpc":"2.0","id":1,"method":"ping"}',
            );
            final response = await readResponse(socket);
            expect(response, contains('403'));
          } finally {
            socket.destroy();
          }
        } finally {
          await server.stop();
        }
      },
    );

    test(
      'authenticated mode skips the loopback Origin/Host enforcement',
      () async {
        final server = await startServer(token: 's3cret', bindAll: true);
        try {
          final socket = await Socket.connect('127.0.0.1', server.port!);
          try {
            // The bearer token authenticates every caller — the same
            // policy the SSE transport documents — so a tunnel client's
            // non-loopback Host is not a rejection here.
            const body = '{"jsonrpc":"2.0","id":1,"method":"ping"}';
            socket.write(
              'POST /mcp HTTP/1.1\r\n'
              'Host: tunnel.zuzu.dev\r\n'
              'Content-Type: application/json\r\n'
              'Authorization: Bearer s3cret\r\n'
              'Content-Length: ${body.length}\r\n'
              '\r\n'
              '$body',
            );
            final response = await readResponse(socket);
            expect(response, contains('200'));
            expect(response, contains('pong'));
          } finally {
            socket.destroy();
          }
        } finally {
          await server.stop();
        }
      },
    );

    test('answers 401 before reading or parsing the body', () async {
      final server = await startServer(token: 's3cret');
      try {
        final client = HttpClient();
        try {
          // Garbage body, no token: the auth gate fires before the read
          // (the 400 parse path would prove the body was buffered
          // first). The id is unread, so the error carries a null id.
          final request = await client.postUrl(
            Uri.parse('http://127.0.0.1:${server.port}/mcp'),
          );
          request.headers.contentType = ContentType.json;
          request.write('not json at all');
          final response = await request.close();
          expect(response.statusCode, 401);
          final body = await response.transform(utf8.decoder).join();
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          expect(decoded['error']['code'], -32001);
          expect(decoded['id'], isNull);
        } finally {
          client.close(force: true);
        }
      } finally {
        await server.stop();
      }
    });

    test('answers a non-UTF-8 body with the 400 parse error', () async {
      final server = await startServer();
      try {
        final client = HttpClient();
        try {
          // Valid Content-Length, invalid UTF-8 payload (a lone 0xFF
          // continuation byte): utf8.decode throws before jsonDecode,
          // so the response follows the parse-error contract (400,
          // -32700, null id) — not the 500 internal-error handler.
          final body = utf8.encode('{"jsonrpc":"2.0","id":1,"method":"ping"}');
          final broken = <int>[
            ...body.sublist(0, 12),
            0xFF,
            ...body.sublist(12),
          ];
          final request = await client.postUrl(
            Uri.parse('http://127.0.0.1:${server.port}/mcp'),
          );
          request.headers.contentType = ContentType.json;
          request.contentLength = broken.length;
          request.add(broken);
          final response = await request.close();
          expect(response.statusCode, 400);
          final decoded =
              jsonDecode(await response.transform(utf8.decoder).join())
                  as Map<String, dynamic>;
          expect(decoded['error']['code'], -32700);
          expect(decoded['id'], isNull);
        } finally {
          client.close(force: true);
        }
      } finally {
        await server.stop();
      }
    });

    test(
      'rejects a declared-oversize body with 413 before reading it',
      () async {
        final server = await startServer(token: 's3cret');
        try {
          final socket = await Socket.connect('127.0.0.1', server.port!);
          try {
            // Content-Length over the cap: the server answers 413 from
            // the header alone, without reading a body byte. The client
            // completes the declared body because dart:io's HttpServer
            // flushes a response only once its parser sees the end of
            // the request — the server never consumes it either way
            // (the cap fired on the header).
            final body = 'a' * (McpStreamableHttpServer.maxBodyBytes + 1);
            socket.write(
              'POST /mcp HTTP/1.1\r\n'
              'Host: 127.0.0.1:${server.port}\r\n'
              'Content-Type: application/json\r\n'
              'Authorization: Bearer s3cret\r\n'
              'Content-Length: ${body.length}\r\n'
              '\r\n'
              '$body',
            );
            final response = await readResponse(socket);
            expect(response, contains('413'));
          } finally {
            socket.destroy();
          }
        } finally {
          await server.stop();
        }
      },
    );

    test(
      'caps a chunked (no Content-Length) body at maxBodyBytes with 413',
      () async {
        final server = await startServer(token: 's3cret');
        try {
          final socket = await Socket.connect('127.0.0.1', server.port!);
          try {
            // No Content-Length, so the cap can only fire on the
            // streamed read. The framing is completed (terminator
            // sent) because dart:io flushes the response only once
            // the chunked body ends — the server's cap fires before
            // that, on the accumulated bytes.
            const chunkSize = 16 * 1024;
            final total = McpStreamableHttpServer.maxBodyBytes + chunkSize;
            final chunkHex = chunkSize.toRadixString(16);
            final chunk = 'a' * chunkSize;
            final chunks = List.generate(
              total ~/ chunkSize,
              (_) => '$chunkHex\r\n$chunk\r\n',
            ).join();
            socket.write(
              'POST /mcp HTTP/1.1\r\n'
              'Host: 127.0.0.1:${server.port}\r\n'
              'Content-Type: application/json\r\n'
              'Authorization: Bearer s3cret\r\n'
              'Transfer-Encoding: chunked\r\n'
              '\r\n'
              '$chunks'
              '0\r\n\r\n',
            );
            final response = await readResponse(socket);
            expect(response, contains('413'));
          } finally {
            socket.destroy();
          }
        } finally {
          await server.stop();
        }
      },
    );
  });
}
