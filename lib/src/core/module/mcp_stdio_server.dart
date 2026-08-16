import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'mcp_tool.dart';
import 'mcp_tool_registry.dart';

/// stdio JSON-RPC 2.0 server that dispatches to a [McpToolRegistry].
///
/// Implements the MCP protocol subset required by issue #369:
///   - `initialize`     → protocolVersion + serverInfo + capabilities
///   - `tools/list`     → registry.toolDefinitions()
///   - `tools/call`     → registry.find(name)?.call(args)
///   - `ping`           → { pong: true }
///   - `shutdown`       → {} (the loop continues until stdin closes)
///
/// Reading: stdin line-by-line (UTF-8), each non-empty line is a
/// JSON-RPC request. Writing: one JSON-RPC response per line to
/// stdout. Notifications (id == null) get no response.
///
/// This is the runtime-tier counterpart of `bin/zuraffa_mcp_server.dart`'s
/// stdio loop, lifted here so any Zuraffa app can run an MCP server
/// without pulling in the codegen-side `zuraffa_mcp_server` binary.
/// The codegen server speaks the same JSON-RPC dialect but dispatches
/// to [PluginRegistry] capabilities (which generate code); this server
/// dispatches to runtime [McpTool]s (which run app features).
class McpStdioServer {
  /// The tool registry backing `tools/list` and `tools/call`.
  final McpToolRegistry registry;

  /// Server name advertised in the `initialize` response.
  final String serverName;

  /// Server version advertised in the `initialize` response.
  final String serverVersion;

  /// MCP protocol version advertised in the `initialize` response.
  /// Matches the codegen server's `2024-11-05` for client-compat.
  static const String defaultProtocolVersion = '2024-11-05';

  /// Optional input stream — defaults to [stdin]. Tests inject a
  /// custom stream to drive the server without spawning a process.
  final Stream<List<int>>? inputStream;

  /// Optional output sink — defaults to [stdout]. Tests inject a
  /// [StringSink] to capture the JSON-RPC responses.
  final StringSink? outputSink;

  /// Optional error sink — defaults to [stderr]. Tests inject a
  /// [StringSink] to capture diagnostic output.
  final StringSink? errorSink;

  McpStdioServer({
    required this.registry,
    this.serverName = 'zuraffa-app-mcp',
    this.serverVersion = '1.0.0',
    this.inputStream,
    this.outputSink,
    this.errorSink,
  });

  /// Runs the stdio loop until the input stream closes.
  ///
  /// In production (no injected [inputStream]) this never returns
  /// — stdin is held open until the process is killed. In tests
  /// (injected stream) it returns when the stream ends.
  Future<void> run() async {
    final stream = (inputStream ?? stdin)
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in stream) {
        if (line.trim().isEmpty) continue;
        await _handleLine(line);
      }
    } catch (e, st) {
      _err('Stream error: $e\n$st');
    }

    // In a real process the loop would never reach here; in tests
    // (injected stream) this is the natural exit.
  }

  /// Dispatches a single JSON-RPC line.
  Future<void> _handleLine(String line) async {
    Map<String, dynamic>? request;
    try {
      request = jsonDecode(line) as Map<String, dynamic>;
    } catch (e) {
      _emit({
        'jsonrpc': '2.0',
        'error': {'code': -32700, 'message': 'Parse error: $e'},
        'id': null,
      });
      return;
    }

    final response = await handleRequest(request);
    if (response != null) {
      _emit(response);
    }
  }

  /// Routes a parsed JSON-RPC [request] to its handler.
  /// Returns the JSON-RPC response map, or `null` for notifications
  /// (requests with `id == null` that should not get a response).
  Future<Map<String, dynamic>?> handleRequest(
    Map<String, dynamic> request,
  ) async {
    final method = request['method'] as String?;
    final id = request['id'];

    switch (method) {
      case 'initialize':
        return _result(id, {
          'protocolVersion': defaultProtocolVersion,
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': {'name': serverName, 'version': serverVersion},
        });
      case 'tools/list':
        return _result(id, {'tools': registry.toolDefinitions()});
      case 'tools/call':
        return await _callTool(
          id,
          (request['params'] as Map<String, dynamic>?) ?? {},
        );
      case 'ping':
        return _result(id, {'pong': true});
      case 'shutdown':
        return _result(id, {});
      default:
        if (id == null) return null;
        return _error(id, -32601, 'Method not found: $method');
    }
  }

  /// Handles a `tools/call` request: looks up the tool by name and
  /// invokes it with the supplied arguments. Tool-level errors are
  /// returned as `isError: true` results (so the model can react to
  /// them); transport-level errors (unknown tool, bad params shape)
  /// are returned as JSON-RPC errors.
  Future<Map<String, dynamic>> _callTool(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    final name = params['name'];
    if (name is! String) {
      return _error(id, -32602, 'Invalid params: missing "name"');
    }
    final args = (params['arguments'] as Map<String, dynamic>?) ?? {};

    final tool = registry.find(name);
    if (tool == null) {
      return _error(id, -32602, 'Unknown tool: $name');
    }

    try {
      final result = await tool.call(args);
      return _result(id, result.toJson());
    } catch (e, st) {
      // Tool threw — surface as a tool-level error result (not a
      // transport error) so the model can reason about it.
      return _result(id, McpToolResult.error('$e\n$st').toJson());
    }
  }

  void _emit(Map<String, dynamic> response) {
    final line = jsonEncode(response);
    if (outputSink != null) {
      outputSink!.writeln(line);
    } else {
      stdout.writeln(line);
    }
  }

  void _err(String message) {
    if (errorSink != null) {
      errorSink!.writeln(message);
    } else {
      stderr.writeln(message);
    }
  }

  Map<String, dynamic> _result(dynamic id, Map<String, dynamic> result) => {
    'jsonrpc': '2.0',
    'result': result,
    'id': id,
  };

  Map<String, dynamic> _error(dynamic id, int code, String message) => {
    'jsonrpc': '2.0',
    'error': {'code': code, 'message': message},
    'id': id,
  };
}
