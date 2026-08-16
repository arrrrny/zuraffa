// ============================================================
// McpSseServer — SSE transport for the runtime MCP server.
//
// Models the wire shape: clients POST JSON-RPC requests to
// `/message?sessionId=<id>` and receive responses as
// `text/event-stream` frames on a long-lived GET to `/sse`.
//
// This is the remote-agent counterpart to [McpStdioServer].
// Both share the same [McpToolRegistry] and JSON-RPC dispatcher;
// only the framing differs. The implementation is deliberately
// minimal — no retries, no keep-alive heartbeats, no SSE-Event-ID
// bookkeeping — and intentionally mirrors the existing WebSocket
// server in `v2_tools.dart:startWebSocketServer` so the two can
// be swapped by changing one line in `lib/main.dart`.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/module/mcp_tool.dart';
import '../core/module/mcp_tool_registry.dart';
import 'auth.dart' show McpAuth;

/// SSE transport for the runtime MCP server.
///
/// Listens on `127.0.0.1:[port]` (or `0.0.0.0` when [authToken] is
/// set, mirroring the WebSocket server's behaviour) and exposes:
///
///  * `GET  /sse`             — opens the SSE stream; the first
///                               event is `endpoint` with the
///                               message POST URL the client should
///                               use. Subsequent events are
///                               JSON-RPC responses to the client's
///                               POSTed requests, keyed by `id`.
///  * `POST /message?sessionId=<id>` — accepts a JSON-RPC request
///                                       body and dispatches it to
///                                       the [McpToolRegistry].
///  * `GET  /health`           — returns `{"status": "ok"}` for
///                               readiness probes.
class McpSseServer {
  final McpToolRegistry registry;
  final String serverName;
  final String serverVersion;
  final String? authToken;

  HttpServer? _server;
  final Map<String, _SseSession> _sessions = {};

  McpSseServer({
    required this.registry,
    this.serverName = 'zuraffa-app-mcp',
    this.serverVersion = '1.0.0',
    this.authToken,
  });

  /// Whether the server is currently listening.
  bool get isRunning => _server != null;

  /// The bound port. Returns `null` before [start] runs or after
  /// [stop]. If [start] was called with port `0` (ephemeral), this
  /// returns the OS-assigned port. Useful for tests.
  int? get boundPort => _server?.port;

  /// Starts listening on [port]. Returns when the server is bound.
  Future<void> start({int port = 8372}) async {
    if (_server != null) {
      throw StateError('McpSseServer is already running.');
    }
    final auth = McpAuth(token: authToken);
    final bindAddress = auth.isEnabled ? '0.0.0.0' : '127.0.0.1';
    _server = await HttpServer.bind(bindAddress, port);
    stderr.writeln(
      '[mcp-sse] Listening on http://$bindAddress:${_server!.port} '
      '(auth: ${auth.isEnabled ? "on" : "off"})',
    );

    _server!.listen((request) async {
      // Auth gate for remote clients.
      final connInfo = request.connectionInfo;
      if (auth.isEnabled && connInfo != null && !connInfo.remoteAddress.isLoopback) {
        final header = request.headers.value('Authorization');
        if (!auth.validateHeader(header)) {
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..write('Unauthorized')
            ..close();
          return;
        }
      }

      final path = request.uri.path;
      if (path == '/health' && request.method == 'GET') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok', 'transport': 'sse'}))
          ..close();
        return;
      }

      if (path == '/sse' && request.method == 'GET') {
        await _handleSseStream(request);
        return;
      }

      if (path == '/message' && request.method == 'POST') {
        await _handleMessagePost(request);
        return;
      }

      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found')
        ..close();
    });
  }

  /// Stops the server. Safe to call after [start] or after a failed
  /// start attempt. Cancels all open SSE streams.
  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
    for (final session in _sessions.values) {
      await session.controller.close();
    }
    _sessions.clear();
  }

  // ----------------------------------------------------------------
  // SSE stream handler
  // ----------------------------------------------------------------

  Future<void> _handleSseStream(HttpRequest request) async {
    final sessionId = _newSessionId();
    final controller = StreamController<String>();
    final session = _SseSession(sessionId, controller, request);
    _sessions[sessionId] = session;

    request.response
      ..bufferOutput = false // critical for SSE — flush writes immediately
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.parse('text/event-stream')
      ..headers.set('Cache-Control', 'no-cache')
      ..headers.set('Connection', 'keep-alive')
      ..headers.set('Access-Control-Allow-Origin', '*');

    // The first event tells the client where to POST messages.
    final endpointEvent = _formatSseEvent(
      'endpoint',
      '/message?sessionId=$sessionId',
    );
    request.response.write(endpointEvent);
    await request.response.flush();

    // Pump subsequent events to the response stream.
    final subscription = controller.stream.listen((event) {
      request.response.write(event);
      request.response.flush();
    });

    // Keep the connection open until the client disconnects.
    await request.response.done.whenComplete(() {
      subscription.cancel();
      _sessions.remove(sessionId);
    });
  }

  // ----------------------------------------------------------------
  // Message POST handler
  // ----------------------------------------------------------------

  Future<void> _handleMessagePost(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    if (sessionId == null || !_sessions.containsKey(sessionId)) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Unknown or missing sessionId')
        ..close();
      return;
    }

    final body = await _readBody(request);
    Map<String, dynamic> rpc;
    try {
      rpc = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Invalid JSON: $e')
        ..close();
      return;
    }

    // Acknowledge receipt immediately (the response goes over SSE).
    request.response
      ..statusCode = HttpStatus.accepted
      ..write('accepted')
      ..close();

    // Dispatch in the background and stream the result back over SSE.
    final session = _sessions[sessionId]!;
    try {
      final response = await _dispatch(rpc);
      if (response != null) {
        final event = _formatSseEvent(
          'message',
          jsonEncode(response),
        );
        session.controller.add(event);
      }
    } catch (e, st) {
      final errorResponse = {
        'jsonrpc': '2.0',
        'error': {'code': -32603, 'message': 'Internal error: $e'},
        'id': rpc['id'],
      };
      session.controller.add(_formatSseEvent('message', jsonEncode(errorResponse)));
      stderr.writeln('[mcp-sse] dispatch error: $e\n$st');
    }
  }

  // ----------------------------------------------------------------
  // JSON-RPC dispatcher — mirrors McpStdioServer.handleRequest
  // ----------------------------------------------------------------

  Future<Map<String, dynamic>?> _dispatch(Map<String, dynamic> request) async {
    final method = request['method'] as String?;
    final id = request['id'];

    switch (method) {
      case 'initialize':
        return {
          'jsonrpc': '2.0',
          'result': {
            'protocolVersion': '2024-11-05',
            'capabilities': {
              'tools': {'listChanged': false},
            },
            'serverInfo': {'name': serverName, 'version': serverVersion},
          },
          'id': id,
        };
      case 'tools/list':
        return {
          'jsonrpc': '2.0',
          'result': {'tools': registry.toolDefinitions()},
          'id': id,
        };
      case 'tools/call':
        final params = (request['params'] as Map<String, dynamic>?) ?? {};
        final name = params['name'];
        if (name is! String) {
          return {
            'jsonrpc': '2.0',
            'error': {'code': -32602, 'message': 'Invalid params: missing "name"'},
            'id': id,
          };
        }
        final args = (params['arguments'] as Map<String, dynamic>?) ?? {};
        final tool = registry.find(name);
        if (tool == null) {
          return {
            'jsonrpc': '2.0',
            'error': {'code': -32602, 'message': 'Unknown tool: $name'},
            'id': id,
          };
        }
        try {
          final result = await tool.call(args);
          return {'jsonrpc': '2.0', 'result': result.toJson(), 'id': id};
        } catch (e, st) {
          return {
            'jsonrpc': '2.0',
            'result': McpToolResult.error('$e\n$st').toJson(),
            'id': id,
          };
        }
      case 'ping':
        return {'jsonrpc': '2.0', 'result': {'pong': true}, 'id': id};
      case 'shutdown':
        return {'jsonrpc': '2.0', 'result': {}, 'id': id};
      default:
        if (id == null) return null;
        return {
          'jsonrpc': '2.0',
          'error': {'code': -32601, 'message': 'Method not found: $method'},
          'id': id,
        };
    }
  }

  // ----------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------

  String _newSessionId() {
    final now = DateTime.now().toUtc().toIso8601String();
    final rand = (Object().hashCode ^ now.hashCode).abs().toRadixString(36);
    return 'sse-$now-$rand';
  }

  String _formatSseEvent(String event, String data) {
    final buf = StringBuffer()
      ..writeln('event: $event')
      ..writeln('data: $data')
      ..writeln();
    return buf.toString();
  }

  Future<String> _readBody(HttpRequest request) async {
    final bytes = await request.fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk as List<int>),
    );
    return utf8.decode(bytes);
  }
}

class _SseSession {
  final String id;
  final StreamController<String> controller;
  final HttpRequest request;

  _SseSession(this.id, this.controller, this.request);
}
