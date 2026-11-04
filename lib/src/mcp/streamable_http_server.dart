// ============================================================
// McpStreamableHttpServer — Streamable HTTP transport for the
// zuraffa_mcp plugin (issue #2046).
//
// The remote twin of [McpStdioServer]: the same JSON-RPC subset
// (initialize, tools/list, tools/call, ping, shutdown) dispatched
// through the shared [McpDispatcher], served over HTTP POST /mcp.
//
// Streamable HTTP (MCP transport spec, 2025-03-26):
//   - POST /mcp  — client→server JSON-RPC message; the response is
//     `application/json` (a stateless server never streams a
//     server→client stream back on the POST channel).
//   - GET /mcp   — would open the server→client SSE stream; this
//     server never pushes server→client messages, so it answers
//     405 Method Not Allowed (explicitly allowed by the spec).
//   - DELETE /mcp — session termination; sessions are not issued,
//     so 405 as well.
//
// Security (issue #2046):
//   - Binds `127.0.0.1` by default; `bindAll: true` (for a tunnel /
//     remote exposure) is refused unless an auth token is configured.
//   - When a token is configured, EVERY request must carry
//     `Authorization: Bearer <token>` — unlike the SSE transport's
//     loopback trust, an HTTP endpoint is reachable from any process
//     on the machine, so the token gates loopback callers too.
//   - Per-token tool allowlists ([McpAuth.isToolAllowed]) gate
//     `tools/call` with the SSE server's -32000 error contract.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/module/mcp_dispatcher.dart';
import '../core/module/mcp_tool_registry.dart';
import 'auth.dart';

/// Streamable HTTP MCP server exposing a [McpToolRegistry] (issue
/// #2046). Stateless: no `Mcp-Session-Id` is issued and none is
/// required — each POST carries exactly one JSON-RPC message and the
/// response is the JSON-RPC reply.
class McpStreamableHttpServer {
  /// The tool registry backing `tools/list` and `tools/call`.
  final McpToolRegistry registry;

  /// Server name advertised in the `initialize` response.
  final String serverName;

  /// Server version advertised in the `initialize` response.
  final String serverVersion;

  /// Bearer token required on every request when non-null (see the
  /// class-level security notes).
  final String? authToken;

  /// Per-token tool allowlists forwarded to [McpAuth].
  final Map<String, Set<String>>? tokenToolAllowlist;

  /// When `true`, binds `0.0.0.0` instead of loopback. Refused at
  /// [start] unless [authToken] is configured — a remote exposure
  /// without a token is exactly what issue #2046 forbids.
  final bool bindAll;

  /// The single HTTP endpoint path (Streamable HTTP convention).
  static const String endpointPath = '/mcp';

  /// JSON-RPC error code for a failed/missing bearer token.
  static const int errorUnauthorized = -32001;

  /// JSON-RPC error code for allowlist denial — matches the SSE
  /// server's contract.
  static const int errorNotPermitted = -32000;

  late final McpDispatcher _dispatcher;
  late final McpAuth _auth;
  HttpServer? _server;

  McpStreamableHttpServer({
    required this.registry,
    this.serverName = 'zuraffa-app-mcp',
    this.serverVersion = '1.0.0',
    this.authToken,
    this.tokenToolAllowlist,
    this.bindAll = false,
  }) {
    _auth = McpAuth(token: authToken, tokenToolAllowlist: tokenToolAllowlist);
    _dispatcher = McpDispatcher(
      registry: registry,
      serverName: serverName,
      serverVersion: serverVersion,
      onToolError: (e, st) {
        stderr.writeln('tools/call error: $e\n$st');
      },
    );
  }

  /// Whether the server is currently bound and serving.
  bool get isRunning => _server != null;

  /// The bound port (resolved even for an ephemeral `port: 0` start),
  /// or `null` before [start] / after [stop].
  int? get port => _server?.port;

  /// Binds and starts serving. Returns when the socket is bound (not
  /// when the server shuts down) — [stop] shuts it down.
  ///
  /// Throws [ArgumentError] when [bindAll] is set without an auth
  /// token (issue #2046's security requirement).
  Future<void> start({int port = 8373}) async {
    if (bindAll && !_auth.isEnabled) {
      throw ArgumentError(
        'McpStreamableHttpServer(bindAll: true) requires an authToken — '
        'a remote MCP exposure without authentication is not allowed '
        '(issue #2046).',
      );
    }
    final address = bindAll
        ? InternetAddress.anyIPv4
        : InternetAddress.loopbackIPv4;
    _server = await HttpServer.bind(address, port);
    _server!.listen(
      _handleRequest,
      onError: (Object e, StackTrace st) {
        stderr.writeln('mcp http server error: $e\n$st');
      },
    );
  }

  /// Stops the server and closes the bound socket.
  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.uri.path != endpointPath) {
        await _respond(request, HttpStatus.notFound, 'Not found');
        return;
      }
      switch (request.method) {
        case 'POST':
          await _handlePost(request);
        case 'GET' || 'DELETE':
          // No server→client stream and no sessions to terminate —
          // both explicitly allowed 405s under Streamable HTTP.
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..headers.set('Allow', 'POST');
          await request.response.close();
        default:
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..headers.set('Allow', 'POST');
          await request.response.close();
      }
    } catch (e, st) {
      stderr.writeln('mcp http request error: $e\n$st');
      try {
        await _respond(
          request,
          HttpStatus.internalServerError,
          'Internal error',
        );
      } catch (_) {
        // Socket already gone — nothing left to answer on.
      }
    }
  }

  Future<void> _handlePost(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();

    // Parse first so a 401 can echo the request id back.
    Map<String, dynamic>? rpc;
    Object? parseError;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        rpc = decoded;
      } else {
        parseError = 'expected a single JSON-RPC object';
      }
    } catch (e) {
      parseError = e;
    }

    // Auth: the bearer token gates EVERY request when configured.
    if (!_auth.validateHeader(request.headers.value('Authorization'))) {
      await _respondJson(
        request,
        HttpStatus.unauthorized,
        {
          'jsonrpc': '2.0',
          'error': {
            'code': errorUnauthorized,
            'message':
                'Unauthorized: a valid bearer token is required for the '
                'HTTP MCP transport',
          },
          'id': rpc?['id'],
        },
        headers: {'WWW-Authenticate': 'Bearer'},
      );
      return;
    }

    if (parseError != null) {
      await _respondJson(request, HttpStatus.badRequest, {
        'jsonrpc': '2.0',
        'error': {'code': -32700, 'message': 'Parse error: $parseError'},
        'id': null,
      });
      return;
    }

    // Per-token tool allowlist (mirrors the SSE server's contract).
    if (rpc!['method'] == 'tools/call') {
      final params = rpc['params'];
      final toolName = params is Map<String, dynamic> ? params['name'] : null;
      if (toolName is String) {
        final callerToken = _auth.tokenFromHeader(
          request.headers.value('Authorization'),
        );
        if (!_auth.isToolAllowed(callerToken, toolName)) {
          await _respondJson(request, HttpStatus.ok, {
            'jsonrpc': '2.0',
            'error': {
              'code': errorNotPermitted,
              'message':
                  'Tool "$toolName" is not permitted for the supplied token',
            },
            'id': rpc['id'],
          });
          return;
        }
      }
    }

    final response = await _dispatcher.dispatch(rpc);
    if (response == null) {
      // Notification (id == null): accepted, nothing to reply with.
      request.response.statusCode = HttpStatus.accepted;
      await request.response.close();
      return;
    }
    await _respondJson(request, HttpStatus.ok, response);
  }

  Future<void> _respondJson(
    HttpRequest request,
    int status,
    Map<String, dynamic> body, {
    Map<String, String> headers = const {},
  }) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json;
    headers.forEach(request.response.headers.set);
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> _respond(HttpRequest request, int status, String message) async {
    request.response.statusCode = status;
    request.response.write(message);
    await request.response.close();
  }
}
