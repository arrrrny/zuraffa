import 'dart:convert';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/di_container.dart';
import 'package:zuraffa/src/core/module/engine.dart';
import 'package:zuraffa/src/core/module/mcp_server_plugin.dart';
import 'package:zuraffa/src/core/module/mcp_tool.dart';

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

void main() {
  group('McpServerPlugin streamable HTTP wiring', () {
    ZuraffaDIContainer freshDi() =>
        ZuraffaDIContainer(getIt: GetIt.asNewInstance());

    test('serveHttp before bootstrap throws StateError', () async {
      final p = McpServerPlugin(tools: [_EchoTool()]);
      expect(() => p.serveHttp(), throwsStateError);
    });

    test(
      'serveHttp exposes the live registry over the streamable HTTP transport',
      () async {
        final engine = ZuraffaEngine(di: freshDi())
          ..register(McpServerPlugin(tools: [_EchoTool()]));
        await engine.bootstrap();
        final plugin = engine['mcp'] as McpServerPlugin;
        await plugin.serveHttp(port: 0);
        final server = plugin.httpServer!;
        try {
          expect(server.isRunning, isTrue);
          final client = HttpClient();
          try {
            final request = await client.postUrl(
              Uri.parse('http://127.0.0.1:${server.port}/mcp'),
            );
            request.headers.contentType = ContentType.json;
            request.write(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': 1,
                'method': 'tools/call',
                'params': {
                  'name': 'echo',
                  'arguments': {'msg': 'via-http'},
                },
              }),
            );
            final response = await request.close();
            expect(response.statusCode, 200);
            final body =
                jsonDecode(await response.transform(utf8.decoder).join())
                    as Map<String, dynamic>;
            final content = body['result']['content'] as List;
            expect(content.first['text'], 'via-http');
          } finally {
            client.close(force: true);
          }
        } finally {
          await server.stop();
        }
      },
    );

    test('autoStartHttpPort starts the HTTP server during bootstrap', () async {
      final engine = ZuraffaEngine(di: freshDi())
        ..register(
          McpServerPlugin(
            tools: [_EchoTool()],
            autoStartHttpPort: 0,
            httpAuthToken: 's3cret',
          ),
        );
      await engine.bootstrap();
      final plugin = engine['mcp'] as McpServerPlugin;
      final server = plugin.httpServer!;
      try {
        expect(server.isRunning, isTrue);
        // A request without the token is rejected: the HTTP transport's
        // auth-token requirement (issue #2046).
        final client = HttpClient();
        try {
          final request = await client.postUrl(
            Uri.parse('http://127.0.0.1:${server.port}/mcp'),
          );
          request.headers.contentType = ContentType.json;
          request.write(
            jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}),
          );
          final response = await request.close();
          expect(response.statusCode, 401);
          await response.drain<void>();
        } finally {
          client.close(force: true);
        }
      } finally {
        await server.stop();
      }
    });

    test(
      'serveHttp refuses a second start while a server is running',
      () async {
        final engine = ZuraffaEngine(di: freshDi())
          ..register(McpServerPlugin(tools: [_EchoTool()]));
        await engine.bootstrap();
        final plugin = engine['mcp'] as McpServerPlugin;
        await plugin.serveHttp(port: 0);
        final first = plugin.httpServer!;
        try {
          expect(first.isRunning, isTrue);
          await expectLater(plugin.serveHttp(port: 0), throwsStateError);
          // The refused start must not disturb the running listener.
          expect(identical(plugin.httpServer, first), isTrue);
          expect(plugin.httpServer!.isRunning, isTrue);
          expect(plugin.httpServer!.port, first.port);
        } finally {
          await first.stop();
        }
      },
    );

    test('a failed bind does not replace the httpServer reference', () async {
      // An unrelated socket occupies a port; the plugin's first
      // (already stopped) server satisfies the running-guard, so the
      // second serveHttp reaches the bind and fails — and because the
      // new server is retained only after a successful start, the
      // failed instance must not replace the retained reference.
      final squatter = await ServerSocket.bind('127.0.0.1', 0);
      final occupied = squatter.port;
      final engine = ZuraffaEngine(di: freshDi())
        ..register(McpServerPlugin(tools: [_EchoTool()]));
      await engine.bootstrap();
      final plugin = engine['mcp'] as McpServerPlugin;
      await plugin.serveHttp(port: 0);
      final first = plugin.httpServer!;
      await first.stop();
      try {
        expect(first.isRunning, isFalse);
        await expectLater(
          plugin.serveHttp(port: occupied),
          throwsA(isA<SocketException>()),
        );
        expect(identical(plugin.httpServer, first), isTrue);
        expect(plugin.httpServer!.isRunning, isFalse);
        expect(plugin.httpServer!.port, isNull);
      } finally {
        await squatter.close();
      }
    });

    test('engine.shutdown stops the auto-started HTTP server', () async {
      final engine = ZuraffaEngine(di: freshDi())
        ..register(
          McpServerPlugin(
            tools: [_EchoTool()],
            autoStartHttpPort: 0,
            httpAuthToken: 's3cret',
          ),
        );
      await engine.bootstrap();
      final server = (engine['mcp'] as McpServerPlugin).httpServer!;
      expect(server.isRunning, isTrue);
      await engine.shutdown();
      expect(server.isRunning, isFalse);
      expect(server.port, isNull);
    });
  });
}
