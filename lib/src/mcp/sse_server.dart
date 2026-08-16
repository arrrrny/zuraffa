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
import 'dart:math';

import '../core/module/mcp_dispatcher.dart';
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
  late final McpDispatcher _dispatcher;

  McpSseServer({
    required this.registry,
    this.serverName = 'zuraffa-app-mcp',
    this.serverVersion = '1.0.0',
    this.authToken,
  }) {
    _dispatcher = McpDispatcher(
      registry: registry,
      serverName: serverName,
      serverVersion: serverVersion,
    );
  }

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
      // Auth gate for remote clients. Treat null connectionInfo as
      // non-loopback (requiring Authorization when auth is enabled).
      final connInfo = request.connectionInfo;
      final isLoopback = connInfo?.remoteAddress.isLoopback ?? false;
      if (auth.isEnabled && !isLoopback) {
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
    // Validate Origin and Host to prevent DNS rebinding attacks.
    if (!_isValidRequest(request)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('Forbidden')
        ..close();
      return;
    }

    final sessionId = _newSessionId();
    final controller = StreamController<String>();
    final session = _SseSession(sessionId, controller, request);
    _sessions[sessionId] = session;

    request.response
      ..bufferOutput = false // critical for SSE — flush writes immediately
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.parse('text/event-stream')
      ..headers.set('Cache-Control', 'no-cache')
      ..headers.set('Connection', 'keep-alive');

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
      request.response.flush().catchError((_) {
        // Client disconnected — ignore flush errors; the done future
        // below will clean up the session.
      });
    });

    // Keep the connection open until the client disconnects. Consume
    // peer-disconnect errors rather than letting them propagate as
    // unhandled async errors.
    await request.response.done.catchError((e) {
      // Peer disconnected — this is expected, not an error.
    }).whenComplete(() {
      subscription.cancel();
      _sessions.remove(sessionId);
    });
  }

  // ----------------------------------------------------------------
  // Message POST handler
  // ----------------------------------------------------------------

  Future<void> _handleMessagePost(HttpRequest request) async {
    // Validate Origin and Host to prevent DNS rebinding attacks.
    if (!_isValidRequest(request)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('Forbidden')
        ..close();
      return;
    }

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

    // Re-read _sessions after the await — the session may have been
    // removed while we were reading the body.
    final session = _sessions[sessionId];
    if (session == null) {
      request.response
        ..statusCode = HttpStatus.gone
        ..write('Session no longer exists')
        ..close();
      return;
    }

    // Acknowledge receipt immediately (the response goes over SSE).
    request.response
      ..statusCode = HttpStatus.accepted
      ..write('accepted')
      ..close();

    // Dispatch in the background and stream the result back over SSE.
    try {
      final response = await _dispatcher.dispatch(rpc);
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
  // Helpers
  // ----------------------------------------------------------------

  /// Validates that the request Origin and Host are safe for local servers.
  /// Returns false if Origin is present but not localhost/127.0.0.1, or if
  /// Host is non-loopback (DNS rebinding protection).
  bool _isValidRequest(HttpRequest request) {
    // Check Origin header against allowlist.
    final origin = request.headers.value('origin');
    if (origin != null) {
      final uri = Uri.tryParse(origin);
      if (uri == null) return false;
      final host = uri.host.toLowerCase();
      if (host != 'localhost' &&
          host != '127.0.0.1' &&
          host != '[::1]') {
        return false;
      }
    }

    // Check Host header to prevent DNS rebinding.
    final host = request.headers.value('host');
    if (host != null) {
      final hostOnly = host.split(':').first.toLowerCase();
      if (hostOnly != 'localhost' &&
          hostOnly != '127.0.0.1' &&
          hostOnly != '[::1]') {
        return false;
      }
    }

    return true;
  }

  String _newSessionId() {
    // Use Random.secure() for session ID entropy, matching McpAuth.generateToken.
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final rand = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'sse-$now-$rand';
  }

  String _formatSseEvent(String event, String data) {
    final buf = StringBuffer()..writeln('event: $event');
    // Per the SSE spec, every line of a multi-line data payload must
    // be prefixed with `data: `. A blank line terminates the event.
    for (final line in data.split('\n')) {
      buf.writeln('data: $line');
    }
    buf.writeln();
    return buf.toString();
  }

  Future<String> _readBody(HttpRequest request) async {
    const maxBodyLength = 1024 * 1024; // 1 MiB
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk as List<int>);
      if (bytes.length > maxBodyLength) {
        // Abort oversized requests with HTTP 413.
        request.response
          ..statusCode = HttpStatus.requestEntityTooLarge
          ..write('Request body too large')
          ..close();
        throw StateError('Request body exceeds maximum length');
      }
    }
    return utf8.decode(bytes);
  }
}

class _SseSession {
  final String id;
  final StreamController<String> controller;
  final HttpRequest request;

  _SseSession(this.id, this.controller, this.request);
}
