import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/mcp_tool.dart';
import 'package:zuraffa/src/core/module/mcp_tool_registry.dart';
import 'package:zuraffa/src/mcp/sse_server.dart';

/// Splits a UTF-8 SSE byte stream into complete frames.
///
/// Buffers decoded chunks across stream boundaries, emits only frames
/// terminated by a blank line (`\n\n`), and retains any incomplete
/// trailing data for the next chunk.
Stream<String> _sseFrames(Stream<List<int>> chunks) async* {
  var buffer = '';
  await for (final chunk in chunks) {
    buffer += utf8.decode(chunk);
    final parts = buffer.split('\n\n');
    buffer = parts.removeLast();
    for (final part in parts) {
      if (part.trim().isNotEmpty) yield part;
    }
  }
  if (buffer.trim().isNotEmpty) yield buffer;
}

void main() {
  group('McpSseServer', () {
    late McpToolRegistry registry;
    late McpSseServer server;
    late int port;
    late HttpClient client;

    setUp(() async {
      registry = McpToolRegistry();
      registry.register(_EchoTool());
      server = McpSseServer(registry: registry);
      await server.start(port: 0);
      port = server.boundPort!;
      client = HttpClient()
        // Bound the TCP connect so a non-reachable non-loopback interface
        // fails fast with a SocketException instead of hanging until the OS
        // TCP timeout — which would otherwise exceed the 30s per-test limit
        // and surface as a spurious "server hang" on unauthenticated 401.
        ..connectionTimeout = const Duration(seconds: 5);
    });

    tearDown(() async {
      await server.stop();
      client.close(force: true);
    });

    test('/health returns 200 with status=ok', () async {
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/health'),
      );
      final res = await req.close();
      expect(res.statusCode, 200);
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['status'], 'ok');
      expect(json['transport'], 'sse');
    });

    test(
      'GET /sse opens an event-stream and emits the endpoint event',
      () async {
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/sse'),
        );
        final res = await req.close();
        expect(res.statusCode, 200);
        expect(res.headers.contentType?.mimeType, 'text/event-stream');

        final firstChunk = await res
            .transform(utf8.decoder)
            .first
            .timeout(const Duration(seconds: 2));
        expect(firstChunk, contains('event: endpoint'));
        expect(firstChunk, contains('data: /message?sessionId='));
      },
    );

    test(
      'full POST round-trip: tools/list returns the registered tool definitions',
      () async {
        // Open SSE and buffer all events into a queue. Each event is
        // a chunk terminated by `\n\n` in the SSE wire format.
        final sseReq = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/sse'),
        );
        final sseRes = await sseReq.close();
        final eventStream = _sseFrames(sseRes);
        final iter = StreamIterator(eventStream);

        // Wait for the endpoint event and extract the sessionId.
        final endpointEvent = await iter.moveNext().timeout(
          const Duration(seconds: 2),
        );
        expect(endpointEvent, isTrue);
        final endpointData = iter.current;
        expect(endpointData, contains('event: endpoint'));
        final sessionId = RegExp(
          r'sessionId=([^\s\n]+)',
        ).firstMatch(endpointData)!.group(1)!;

        // POST a tools/list request.
        final postReq = await client.postUrl(
          Uri.parse('http://127.0.0.1:$port/message?sessionId=$sessionId'),
        );
        postReq.headers.contentType = ContentType.json;
        postReq.write(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'}),
        );
        final postRes = await postReq.close();
        expect(postRes.statusCode, anyOf(200, 202));

        // Wait for the message event carrying the tools/list response.
        final got = await iter.moveNext().timeout(const Duration(seconds: 3));
        expect(got, isTrue);
        final msgData = iter.current;
        expect(msgData, contains('event: message'));
        final dataMatch = RegExp(
          r'^data: (.+)$',
          multiLine: true,
        ).firstMatch(msgData)!;
        final responseJson =
            jsonDecode(dataMatch.group(1)!) as Map<String, dynamic>;
        final tools = (responseJson['result'] as Map)['tools'] as List;
        expect(tools.length, 1);
        expect((tools.single as Map)['name'], 'echo');

        await iter.cancel();
      },
    );

    test(
      'POST /message dispatches a tools/call and streams the result',
      () async {
        final sseReq = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/sse'),
        );
        final sseRes = await sseReq.close();
        final eventStream = _sseFrames(sseRes);
        final iter = StreamIterator(eventStream);

        // First event: endpoint announcement.
        await iter.moveNext().timeout(const Duration(seconds: 2));
        final endpointData = iter.current;
        final sessionId = RegExp(
          r'sessionId=([^\s\n]+)',
        ).firstMatch(endpointData)!.group(1)!;

        // POST a tools/call request.
        final postReq = await client.postUrl(
          Uri.parse('http://127.0.0.1:$port/message?sessionId=$sessionId'),
        );
        postReq.headers.contentType = ContentType.json;
        postReq.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 42,
            'method': 'tools/call',
            'params': {
              'name': 'echo',
              'arguments': {'message': 'hello sse'},
            },
          }),
        );
        await postReq.close();

        // Second event: the response to our tools/call.
        await iter.moveNext().timeout(const Duration(seconds: 3));
        final msgData = iter.current;
        expect(msgData, contains('event: message'));
        final dataMatch = RegExp(
          r'^data: (.+)$',
          multiLine: true,
        ).firstMatch(msgData)!;
        final responseJson =
            jsonDecode(dataMatch.group(1)!) as Map<String, dynamic>;
        expect(responseJson['id'], 42);
        final result = responseJson['result'] as Map<String, dynamic>;
        final content = result['content'] as List;
        expect((content.single as Map)['text'], 'echo: hello sse');

        await iter.cancel();
      },
    );

    test('unknown path returns 404', () async {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/nope'));
      final res = await req.close();
      expect(res.statusCode, 404);
    });

    test('POST /message without sessionId returns 400', () async {
      final req = await client.postUrl(
        Uri.parse('http://127.0.0.1:$port/message'),
      );
      req.headers.contentType = ContentType.json;
      req.write('{}');
      final res = await req.close();
      expect(res.statusCode, 400);
    });

    test('SSE with auth token accepts non-loopback Origin', () async {
      final authRegistry = McpToolRegistry();
      authRegistry.register(_EchoTool());
      final authServer = McpSseServer(
        registry: authRegistry,
        authToken: 'secret',
      );
      await authServer.start(port: 0);
      final authPort = authServer.boundPort!;

      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:$authPort/sse'),
      );
      req.headers.set('Origin', 'http://example.com');
      final res = await req.close();

      expect(res.statusCode, 200);
      expect(res.headers.contentType?.mimeType, 'text/event-stream');

      await authServer.stop();
    });

    test(
      'remote requests get 401 when Authorization is missing or invalid',
      () async {
        // Start a token-protected server. With a token set the server
        // binds 0.0.0.0, so a request made from a non-loopback address
        // must present a valid Bearer token.
        final authServer = McpSseServer(
          registry: registry,
          authToken: 'secret-token',
        );
        await authServer.start(port: 0);
        final authPort = authServer.boundPort!;
        try {
          // Find a non-loopback IPv4 address to act as the "remote"
          // peer. Skip when the host has none (offline environments).
          List<NetworkInterface> interfaces;
          try {
            interfaces = await NetworkInterface.list(
              type: InternetAddressType.IPv4,
            );
          } catch (_) {
            interfaces = const [];
          }
          final remote = interfaces
              .expand((i) => i.addresses)
              .where((a) => !a.isLoopback)
              .firstOrNull;
          if (remote == null) {
            markTestSkipped('No non-loopback IPv4 interface available.');
            return;
          }
          final base = 'http://${remote.address}:$authPort';

          // Self-connecting to the machine's LAN IP is environment
          // dependent (some hosts/firewalls drop it). Retry the first
          // request briefly; if the interface is unreachable, skip
          // rather than fail on an environment constraint.
          Future<HttpClientResponse> getWithRetry(
            Uri uri, {
            String? authorization,
          }) async {
            for (var attempt = 0; ; attempt++) {
              try {
                final req = await client.getUrl(uri);
                if (authorization != null) {
                  req.headers.set('Authorization', authorization);
                }
                // Bound the response read as well: if the chosen non-loopback
                // interface is unreachable (packet silently dropped), fail fast
                // rather than block until the 30s per-test timeout.
                return await req.close().timeout(const Duration(seconds: 5));
              } on SocketException {
                if (attempt >= 2) rethrow;
                await Future<void>.delayed(const Duration(milliseconds: 300));
              } on HttpException {
                if (attempt >= 2) rethrow;
                await Future<void>.delayed(const Duration(milliseconds: 300));
              } on TimeoutException {
                if (attempt >= 2) rethrow;
                await Future<void>.delayed(const Duration(milliseconds: 300));
              }
            }
          }

          // Missing Authorization header → 401.
          HttpClientResponse resMissing;
          try {
            resMissing = await getWithRetry(Uri.parse('$base/health'));
          } on SocketException {
            markTestSkipped(
              'Cannot reach the machine\'s own non-loopback interface.',
            );
            return;
          } on HttpException {
            markTestSkipped(
              'Cannot reach the machine\'s own non-loopback interface.',
            );
            return;
          } on TimeoutException {
            markTestSkipped(
              'Cannot reach the machine\'s own non-loopback interface.',
            );
            return;
          }
          expect(resMissing.statusCode, HttpStatus.unauthorized);
          await resMissing.drain();

          // Invalid token → 401.
          final resBad = await getWithRetry(
            Uri.parse('$base/health'),
            authorization: 'Bearer wrong-token',
          );
          expect(resBad.statusCode, HttpStatus.unauthorized);
          await resBad.drain();

          // Valid token → 200.
          final resGood = await getWithRetry(
            Uri.parse('$base/health'),
            authorization: 'Bearer secret-token',
          );
          expect(resGood.statusCode, HttpStatus.ok);
          await resGood.drain();
        } finally {
          await authServer.stop();
        }
      },
    );
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
    return McpToolResult.ok('echo: ${arguments['message']}');
  }
}
