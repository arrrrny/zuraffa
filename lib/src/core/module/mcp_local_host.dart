import 'mcp_tool.dart';
import 'mcp_tool_registry.dart';

/// Transport-free host surface for the runtime MCP server.
///
/// [LocalMcpHost] wraps an [McpToolRegistry] and exposes the same
/// enumerate/call operations the stdio and SSE transports do — but with
/// no socket, no JSON-RPC framing, and no serialization. It is the
/// server-side half of the in-process bridge used by ZikZak AI's agent
/// runtime.
///
/// The client half is dart_agent_core's `LocalMcpTransport`, which talks
/// to a `LocalMcpHost` interface defined in arrrrny/dart_agent_core#2.
/// Once that interface lands, this class should `implements` it so the
/// two halves line up (zuraffa#384, requirement #2). Until then it is the
/// standalone, transport-free call surface for in-process tool invocation.
class LocalMcpHost {
  final McpToolRegistry _registry;

  /// Wraps [registry] as a transport-free host.
  LocalMcpHost(this._registry);

  /// Tool definitions for `tools/list` — `name`, `description`,
  /// `inputSchema` — in insertion order.
  List<Map<String, dynamic>> listTools() => _registry.toolDefinitions();

  /// Names of all registered tools, in insertion order.
  List<String> get toolNames => _registry.toolNames;

  /// Calls [toolName] with [args] without any transport. Returns an
  /// [McpToolResult]; never throws across the boundary. Unknown tools and
  /// handler exceptions surface as tool-level error results.
  Future<McpToolResult> callTool(String toolName, Map<String, dynamic> args) =>
      _registry.call(toolName, args);
}
