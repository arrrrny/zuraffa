import 'dart:async';

import 'mcp_tool.dart';
import 'mcp_tool_registry.dart';

/// Shared JSON-RPC 2.0 dispatcher for the runtime MCP servers.
///
/// Handles the MCP protocol subset used by both the stdio and SSE
/// transports: `initialize`, `tools/list`, `tools/call`, `ping`, and
/// `shutdown`. Unknown methods receive a JSON-RPC -32601 error, and
/// invalid `tools/call` parameters receive a -32602 error. Tool
/// handlers that throw are converted to tool-level error results
/// (not transport errors).
class McpDispatcher {
  static const String protocolVersion = '2024-11-05';

  final McpToolRegistry registry;
  final String serverName;
  final String serverVersion;

  /// Optional callback invoked when a tool handler throws. Receives the
  /// caught error and its stack trace so the transport can log them to
  /// its diagnostic sink while the wire response carries only the
  /// exception message (never internal paths or call structure).
  final void Function(Object error, StackTrace stackTrace)? onToolError;

  McpDispatcher({
    required this.registry,
    this.serverName = 'zuraffa-app-mcp',
    this.serverVersion = '1.0.0',
    this.onToolError,
  });

  /// Dispatches a parsed JSON-RPC [request] and returns the response
  /// map, or `null` for notifications (requests with `id == null`).
  Future<Map<String, dynamic>?> dispatch(Map<String, dynamic> request) async {
    final id = request['id'];
    final method = request['method'];

    if (method is! String) {
      return _error(id, -32600, 'Invalid Request: method must be a string');
    }

    switch (method) {
      case 'initialize':
        return _result(id, {
          'protocolVersion': protocolVersion,
          'serverInfo': {'name': serverName, 'version': serverVersion},
          'capabilities': {
            'tools': {'listChanged': true},
          },
        });
      case 'tools/list':
        return _result(id, {'tools': registry.toolDefinitions()});
      case 'tools/call':
        return _handleToolCall(id, request['params']);
      case 'ping':
        return _result(id, {'pong': true});
      case 'shutdown':
        return _result(id, {});
      default:
        return _error(id, -32601, 'Method not found: $method');
    }
  }

  Future<Map<String, dynamic>?> _handleToolCall(
    dynamic id,
    dynamic params,
  ) async {
    if (params is! Map<String, dynamic>) {
      return _error(id, -32602, 'Invalid params: params must be an object');
    }

    final name = params['name'];
    if (name is! String) {
      return _error(id, -32602, 'Invalid params: missing or non-string name');
    }

    final tool = registry.find(name);
    if (tool == null) {
      return _error(id, -32602, 'Unknown tool: $name');
    }

    final arguments = params['arguments'];
    if (arguments != null && arguments is! Map<String, dynamic>) {
      return _error(id, -32602, 'Invalid params: arguments must be an object');
    }
    final args = arguments as Map<String, dynamic>? ?? <String, dynamic>{};

    try {
      final result = await tool.call(args);
      return _result(id, result.toJson());
    } catch (e, st) {
      // Tool-level failure: surface as an isError result so the MCP
      // client sees it as a tool problem, not a transport error. Log
      // the full stack to the diagnostic sink; the wire response
      // carries only the exception message.
      onToolError?.call(e, st);
      return _result(id, McpToolResult.error(e.toString()).toJson());
    }
  }

  Map<String, dynamic>? _result(dynamic id, Object? result) {
    if (id == null) return null;
    return {'jsonrpc': '2.0', 'id': id, 'result': result};
  }

  Map<String, dynamic>? _error(dynamic id, int code, String message) {
    if (id == null) return null;
    return {
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message},
    };
  }
}
