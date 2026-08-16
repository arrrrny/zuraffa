import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'mcp_dispatcher.dart';
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
  static const String defaultProtocolVersion = McpDispatcher.protocolVersion;

  /// Shared dispatcher for JSON-RPC method routing.
  late final McpDispatcher _dispatcher;

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
  }) {
    _dispatcher = McpDispatcher(
      registry: registry,
      serverName: serverName,
      serverVersion: serverVersion,
    );
  }

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
    dynamic requestId;
    try {
      request = jsonDecode(line) as Map<String, dynamic>;
      requestId = request['id'];
    } catch (e) {
      _emit({
        'jsonrpc': '2.0',
        'error': {'code': -32700, 'message': 'Parse error: $e'},
        'id': null,
      });
      return;
    }

    try {
      final response = await handleRequest(request);
      if (response != null) {
        _emit(response);
      }
    } catch (e, st) {
      // Catch per-request failures (invalid params, argument type errors,
      // etc.) and emit a JSON-RPC error response. Preserve request ID
      // when available so the client can match the error to its request.
      _err('handleRequest error: $e\n$st');
      _emit({
        'jsonrpc': '2.0',
        'error': {'code': -32602, 'message': 'Invalid params: $e'},
        'id': requestId,
      });
    }
  }

  /// Routes a parsed JSON-RPC [request] to its handler.
  /// Returns the JSON-RPC response map, or `null` for notifications
  /// (requests with `id == null` that should not get a response).
  ///
  /// Delegates to the shared [McpDispatcher] for method routing.
  Future<Map<String, dynamic>?> handleRequest(
    Map<String, dynamic> request,
  ) async {
    return _dispatcher.dispatch(request);
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
}
