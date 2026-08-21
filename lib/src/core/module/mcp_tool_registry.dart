import 'dart:collection';

import 'mcp_tool.dart';

/// In-process registry of [McpTool]s exposed by a Zuraffa app.
///
/// The [McpServerPlugin] populates this registry during the engine's
/// `registerDependencies` phase (one [register] call per declared
/// tool). The runtime MCP servers ([McpStdioServer], SSE server)
/// then resolve tool names → [McpTool] instances via [find] when a
/// `tools/call` JSON-RPC request arrives.
///
/// This is the "handler dispatch through the DI tree" the MCP plugin
/// issue (#369) requires: tools are registered as part of the app's
/// DI bootstrap (via [McpServerPlugin]) and the registry is the
/// single source of truth for the tool surface.
class McpToolRegistry {
  // Dart's `<K, V>{}` literal preserves insertion order by default
  // (the underlying impl is a LinkedHashMap), so we don't need to
  // spell that out. Kept as a Map for the `values` iteration order.
  final Map<String, McpTool> _tools = <String, McpTool>{};

  /// Registers a [tool]. Throws [StateError] if a tool with the same
  /// name is already registered (callers can pass `override: true`
  /// to replace an existing registration — useful in tests).
  void register(McpTool tool, {bool override = false}) {
    if (!override && _tools.containsKey(tool.name)) {
      throw StateError(
        'A McpTool named "${tool.name}" is already registered. '
        'Pass override: true to replace it.',
      );
    }
    _tools[tool.name] = tool;
  }

  /// Removes the tool named [name] from the registry. Returns the
  /// removed tool, or `null` if no such tool was registered.
  McpTool? unregister(String name) {
    final removed = _tools.remove(name);
    return removed;
  }

  /// Looks up the tool registered under [name], or `null`.
  McpTool? find(String name) => _tools[name];

  /// All registered tools, in insertion order.
  List<McpTool> get allTools =>
      UnmodifiableListView<McpTool>(_tools.values.toList());

  /// All registered tool names, in insertion order.
  List<String> get toolNames =>
      UnmodifiableListView<String>(_tools.keys.toList());

  /// Number of registered tools.
  int get length => _tools.length;

  /// Whether any tools are registered.
  bool get isEmpty => _tools.isEmpty;

  /// Builds the MCP `tools/list` result list — one entry per
  /// registered tool with `name`, `description`, `inputSchema`.
  List<Map<String, dynamic>> toolDefinitions() {
    return _tools.values
        .map((t) => {
          'name': t.name,
          'description': t.description,
          'inputSchema': t.inputSchema,
        })
        .toList(growable: false);
  }

  /// Clears all registered tools. Test-only — production callers
  /// should never invoke this.
  void clear() {
    _tools.clear();
  }
}
