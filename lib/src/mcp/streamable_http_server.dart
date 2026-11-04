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
// Exactly ONE JSON-RPC object per POST — batch arrays are rejected.
// This is deliberate and spec-consistent: the 2025-03-26 revision the
// transport implements REMOVED batching. `McpDispatcher.protocolVersion`
// (2024-11-05) is the library-wide baseline constant shared with the
// stdio/SSE transports, not a promise that batch requests are accepted
// here — a 2024-11-05 client that batches on this transport gets a
// parse-level 400, by design.
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
//   - Browser-surface validation runs BEFORE the body is read:
//     `Content-Type` must be `application/json` (a cross-origin
//     `fetch` with `mode: 'no-cors'` can only send text/plain, so
//     this forces the preflight this server answers 405), and in
//     unauthenticated mode Origin/Host must be loopback (kills
//     cross-origin POSTs and DNS rebinding — the SSE transport's
//     `_isValidRequest` policy). With a token configured the bearer
//     gate below authenticates every caller, so loopback enforcement
//     is skipped, exactly as on the SSE transport.
//   - The bearer token is checked before the request body is read and
//     bodies are capped at [maxBodyBytes] — an unauthenticated or
//     oversized caller can never buffer memory server-side.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  /// Maximum accepted request body. 1 MiB is a generous ceiling for
  /// every JSON-RPC method [McpDispatcher] knows — the cap exists so
  /// no caller (authenticated or not) can pin memory with a huge POST.
  static const int maxBodyBytes = 1 << 20;

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
    // Browser-surface validation before anything is read or parsed
    // (see the class-level security notes).
    if (!_isAcceptableRequest(request)) {
      await _respond(request, HttpStatus.forbidden, 'Forbidden');
      return;
    }

    // Auth BEFORE the body is read: an unauthenticated caller must not
    // be able to buffer memory server-side. The body (and with it the
    // request id) is still unread here, so the 401 answers with a null
    // id — the JSON-RPC shape for "id unknown".
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
          'id': null,
        },
        headers: {'WWW-Authenticate': 'Bearer'},
      );
      return;
    }

    // Body cap: reject a declared-oversize body before reading a byte;
    // the streamed read below enforces the same cap for chunked
    // bodies (which carry no Content-Length).
    if (request.contentLength > maxBodyBytes) {
      await _respond(
        request,
        HttpStatus.requestEntityTooLarge,
        'Payload too large',
      );
      return;
    }
    final body = await _readBody(request);
    if (body == null) {
      await _respond(
        request,
        HttpStatus.requestEntityTooLarge,
        'Payload too large',
      );
      return;
    }

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
          if (rpc['id'] == null) {
            // A notification gets NO response object — JSON-RPC 2.0
            // forbids replying to an id-less message, so an
            // allowlist-denied notification follows the same 202 +
            // no-body contract as the dispatch-null branch below.
            request.response.statusCode = HttpStatus.accepted;
            await request.response.close();
            return;
          }
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

  /// Validates request shape BEFORE the body is read or parsed — the
  /// browser-surface defense, mirroring the SSE transport's
  /// `_isValidRequest` policy:
  ///
  /// - `Content-Type` must be `application/json`. A cross-origin
  ///   `fetch(..., {mode: 'no-cors'})` can only send CORS-safelisted
  ///   types (text/plain), so requiring JSON forces the preflight —
  ///   which this stateless server already answers 405.
  /// - When NO token is configured (the default loopback posture, the
  ///   one any web page the user visits can reach), Origin and Host
  ///   must be loopback: that rejects cross-origin POSTs (foreign
  ///   Origin) and DNS rebinding (foreign Host).
  /// - With a token configured, the bearer gate below authenticates
  ///   every caller, so loopback enforcement is skipped — the same
  ///   policy the SSE transport documents.
  bool _isAcceptableRequest(HttpRequest request) {
    final contentType = request.headers.contentType;
    if (contentType == null || contentType.mimeType != 'application/json') {
      return false;
    }
    if (_auth.isEnabled) return true;
    final origin = request.headers.value('Origin');
    if (origin != null) {
      final uri = Uri.tryParse(origin);
      if (uri == null) return false;
      if (!_isLoopbackHost(uri.host)) return false;
    }
    final hostHeader = request.headers.value('Host');
    if (hostHeader != null && !_isLoopbackHost(_hostFromHeader(hostHeader))) {
      return false;
    }
    return true;
  }

  /// Whether a host string is loopback: `localhost`, `127.0.0.1` or
  /// `::1`, with IPv6 bracket forms normalized. Mirrors the SSE
  /// transport's `_normalizeHost` shape.
  bool _isLoopbackHost(String host) {
    var lower = host.toLowerCase();
    if (lower.startsWith('[') && lower.endsWith(']')) {
      lower = lower.substring(1, lower.length - 1);
    }
    return lower == 'localhost' || lower == '127.0.0.1' || lower == '::1';
  }

  /// Host portion of a Host header value, port stripped and IPv6
  /// bracket form preserved ("[::1]:8373" → "[::1]"). Mirrors the SSE
  /// transport's `_extractHostFromHostHeader`.
  String _hostFromHeader(String hostHeader) {
    final trimmed = hostHeader.trim();
    if (trimmed.startsWith('[')) {
      final closeBracket = trimmed.indexOf(']');
      if (closeBracket > 0) return trimmed.substring(0, closeBracket + 1);
      return trimmed;
    }
    final colon = trimmed.indexOf(':');
    return colon >= 0 ? trimmed.substring(0, colon) : trimmed;
  }

  /// Reads the request body under the [maxBodyBytes] cap. Returns
  /// `null` when the body exceeds the cap — the caller answers 413
  /// without buffering the rest. This is the chunked-body half of the
  /// Content-Length fast path above.
  Future<String?> _readBody(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > maxBodyBytes) return null;
    }
    return utf8.decode(builder.takeBytes());
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
