// X-Ray Bridge HTTP/WebSocket server.
//
// Exposes three REST endpoints and a WebSocket for real-time tree diffs.
// Only starts in debug/profile mode. In release mode, every method is a no-op.
//
// Endpoints:
//   GET  /xray/tree           → JSON tree snapshot
//   POST /xray/action         → invoke a bound action by nodeId
//   POST /xray/control-deck   → trigger a synthetic mock by name
//   WS   /xray/ws             → real-time tree diff stream
//
// Auth:
//   - Localhost binding in dev mode (default).
//   - Configurable bearer token for remote agent access.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'xray_bridge.dart';
import 'xray_scope.dart';

// ------------------------------------------------------------------
// Scope holder — allows registering the active scope with the bridge.
// ------------------------------------------------------------------

/// Holds a reference to the currently active [XRayScopeState].
///
/// Set this in your app's widget tree (e.g. in a State's initState)
/// so the bridge can serialize the tree.
class XRayBridgeScopeHolder {
  XRayBridgeScopeHolder._();

  static XRayScopeState? _activeScope;

  /// Register the active scope.
  static void setScope(XRayScopeState scope) {
    if (kReleaseMode) return;
    _activeScope = scope;
  }

  /// Clear the active scope (e.g. on dispose).
  static void clearScope() {
    _activeScope = null;
  }

  /// Get the current active scope, if any.
  static XRayScopeState? get activeScope {
    if (kReleaseMode) return null;
    return _activeScope;
  }

  /// Clear for testing.
  @visibleForTesting
  static void reset() {
    _activeScope = null;
  }
}

// ------------------------------------------------------------------
// Bridge server
// ------------------------------------------------------------------

/// X-Ray Bridge HTTP + WebSocket server.
///
/// Call [start] to begin listening. The server binds to
/// [InternetAddress.loopbackIPv4] by default (localhost-only).
/// Set [authToken] to require a Bearer token for remote access.
///
/// In release mode, [start] is a no-op and [isRunning] is always false.
class XRayBridgeServer {
  /// Default port for the X-Ray bridge.
  static const int defaultPort = 8471;

  HttpServer? _server;
  final String? _authToken;
  final bool _localhostOnly;
  int _port;

  /// Whether the server is currently running.
  bool get isRunning => _server != null;

  /// The actual port the server is listening on.
  int get port => _port;

  XRayBridgeServer({
    int port = defaultPort,
    String? authToken,
    bool localhostOnly = true,
  })  : _port = port,
        _authToken = authToken,
        _localhostOnly = localhostOnly;

  /// Start the bridge server.
  ///
  /// Returns the actual port the server bound to.
  /// In release mode, returns -1 and does nothing.
  Future<int> start() async {
    if (kReleaseMode) return -1;
    if (_server != null) return _port;

    final address = _localhostOnly
        ? InternetAddress.loopbackIPv4
        : InternetAddress.anyIPv4;

    _server = await HttpServer.bind(address, _port);
    _port = _server!.port;
    _server!.listen(_handleRequest);
    return _port;
  }

  /// Stop the bridge server.
  Future<void> stop() async {
    final server = _server;
    if (server == null) return;
    await server.close(force: true);
    _server = null;
  }

  // ----------------------------------------------------------------
  // Request routing
  // ----------------------------------------------------------------

  void _handleRequest(HttpRequest request) {
    // Auth check
    if (_authToken != null) {
      final authHeader = request.headers.value('authorization');
      final expected = 'Bearer $_authToken';
      if (authHeader != expected) {
        _jsonResponse(request, 401, {
          'error': 'Unauthorized',
          'message': 'Missing or invalid Bearer token',
        });
        return;
      }
    }

    // Release mode guard
    if (kReleaseMode) {
      _jsonResponse(request, 404, {
        'error': 'Not available',
        'message': 'X-Ray bridge is disabled in release mode',
      });
      return;
    }

    // WebSocket upgrade
    if (request.headers.value('upgrade')?.toLowerCase() == 'websocket') {
      _handleWebSocket(request);
      return;
    }

    // REST routing
    final path = request.uri.path;
    final method = request.method;

    if (method == 'GET' && path == '/xray/tree') {
      _handleGetTree(request);
    } else if (method == 'POST' && path == '/xray/action') {
      _handlePostAction(request);
    } else if (method == 'POST' && path == '/xray/control-deck') {
      _handlePostControlDeck(request);
    } else {
      _jsonResponse(request, 404, {
        'error': 'Not found',
        'message':
            'Available endpoints: /xray/tree, /xray/action, /xray/control-deck, /xray/ws',
      });
    }
  }

  // ----------------------------------------------------------------
  // GET /xray/tree
  // ----------------------------------------------------------------

  Future<void> _handleGetTree(HttpRequest request) async {
    final scope = XRayBridgeScopeHolder.activeScope;
    if (scope == null) {
      _jsonResponse(request, 503, {
        'error': 'No active scope',
        'message':
            'No XRayScope is currently registered. Ensure X-Ray mode is enabled and a view is mounted.',
      });
      return;
    }

    final tree = serializeXRayTree(scope);
    _jsonResponse(request, 200, tree.toJson());
  }

  // ----------------------------------------------------------------
  // POST /xray/action
  // ----------------------------------------------------------------

  Future<void> _handlePostAction(HttpRequest request) async {
    try {
      final body = await _readJsonBody(request);
      final targetNode = body['targetNode'] as String?;
      final payload = body['payload'] as Map<String, dynamic>?;

      if (targetNode == null || targetNode.isEmpty) {
        _jsonResponse(request, 400, {
          'error': 'Bad request',
          'message': 'Field "targetNode" is required',
        });
        return;
      }

      final invoked = XRayActionRegistry.invoke(targetNode, payload ?? {});
      if (invoked) {
        _jsonResponse(request, 200, {
          'success': true,
          'targetNode': targetNode,
          'message': 'Action invoked',
        });
      } else {
        _jsonResponse(request, 404, {
          'error': 'Node not found',
          'message': 'No registered action for "$targetNode"',
          'availableNodes': XRayActionRegistry.registeredIds,
        });
      }
    } catch (e) {
      _jsonResponse(request, 400, {
        'error': 'Bad request',
        'message': 'Invalid JSON body: $e',
      });
    }
  }

  // ----------------------------------------------------------------
  // POST /xray/control-deck
  // ----------------------------------------------------------------

  Future<void> _handlePostControlDeck(HttpRequest request) async {
    try {
      final body = await _readJsonBody(request);
      final mockName = body['mockName'] as String?;
      final payload = body['payload'];

      if (mockName == null || mockName.isEmpty) {
        _jsonResponse(request, 400, {
          'error': 'Bad request',
          'message': 'Field "mockName" is required',
        });
        return;
      }

      final triggered = XRayMockInjectorRegistry.trigger(mockName, payload);
      if (triggered) {
        _jsonResponse(request, 200, {
          'success': true,
          'mockName': mockName,
          'message': 'Mock injected',
        });
      } else {
        _jsonResponse(request, 404, {
          'error': 'Mock not found',
          'message': 'No registered mock named "$mockName"',
          'availableMocks': XRayMockInjectorRegistry.registeredNames,
        });
      }
    } catch (e) {
      _jsonResponse(request, 400, {
        'error': 'Bad request',
        'message': 'Invalid JSON body: $e',
      });
    }
  }

  // ----------------------------------------------------------------
  // WebSocket /xray/ws — tree diff stream
  // ----------------------------------------------------------------

  void _handleWebSocket(HttpRequest request) {
    final scope = XRayBridgeScopeHolder.activeScope;
    if (scope == null) {
      // Reject upgrade — no scope to stream
      request.response.statusCode = 503;
      request.response.write(jsonEncode({
        'error': 'No active scope',
      }));
      request.response.close();
      return;
    }

    // Accept the WebSocket upgrade
    final wsFuture = WebSocketTransformer.upgrade(request);
    wsFuture.then((webSocket) {
      // Send initial tree snapshot
      final tree = serializeXRayTree(scope);
      webSocket.add(jsonEncode({
        'type': 'snapshot',
        'data': tree.toJson(),
      }));

      // Subscribe to tree diffs
      StreamSubscription<XRayTreeDiff>? subscription;
      subscription = XRayBridgeStream.stream.listen((diff) {
        if (webSocket.readyState == WebSocket.open) {
          webSocket.add(jsonEncode({
            'type': 'diff',
            'data': diff.toJson(),
          }));
        }
      });

      // Clean up on close
      webSocket.done.whenComplete(() {
        subscription?.cancel();
      });
    }).catchError((e) {
      stderr.writeln('[xray-bridge] WebSocket upgrade error: $e');
    });
  }

  // ----------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------

  Future<void> _jsonResponse(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.set('Content-Type', 'application/json');
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }
}
