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

  /// Names currently disabled via [disable] (issue #2046: per-tool
  /// enable/disable). Disabled tools stay registered (so [find] still
  /// resolves them) but are hidden from `tools/list` and rejected on
  /// `tools/call`.
  final Set<String> _disabled = <String>{};

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

  /// Disables the tool named [name] (issue #2046: per-tool
  /// enable/disable). Idempotent; a name that is not registered is
  /// recorded but has no observable effect until such a tool is
  /// registered (it starts out disabled).
  void disable(String name) => _disabled.add(name);

  /// Re-enables the tool named [name]. Idempotent.
  void enable(String name) => _disabled.remove(name);

  /// Whether the tool named [name] is registered AND enabled.
  bool isEnabled(String name) =>
      _tools.containsKey(name) && !_disabled.contains(name);

  /// Transport-free tool invocation — the server-side half of the
  /// in-process bridge (the client half is dart_agent_core's
  /// `LocalMcpTransport`, which talks to the `LocalMcpHost` interface
  /// this registry backs; see zuraffa#384, requirement #2).
  ///
  /// Looks up [name], validates [args], invokes the tool, and converts
  /// handler throws into tool-level error results (never transport
  /// errors). Returns an error [McpToolResult] (never throws) for
  /// unknown tools or invalid args, so in-process callers and the
  /// SSE/stdio dispatchers share one failure contract.
  Future<McpToolResult> call(String name, Map<String, dynamic> args) async {
    final tool = find(name);
    if (tool == null) {
      return McpToolResult.error('Unknown tool: $name');
    }
    if (!isEnabled(name)) {
      return McpToolResult.error('Tool "$name" is disabled');
    }
    try {
      return await tool.call(args);
    } catch (e, st) {
      // Tool-level failure: surface as isError, never as a transport error.
      return McpToolResult.error(e.toString(), data: {'stack': st.toString()});
    }
  }

  /// All registered, enabled tools, in insertion order (disabled tools
  /// are hidden from the exposed surface — issue #2046). Use [find]
  /// for the raw lookup that ignores the enabled gate.
  List<McpTool> get allTools => UnmodifiableListView<McpTool>(
    _tools.values.where((t) => isEnabled(t.name)).toList(),
  );

  /// All registered, enabled tool names, in insertion order.
  List<String> get toolNames =>
      UnmodifiableListView<String>(_tools.keys.where(isEnabled).toList());

  /// Number of registered tools.
  int get length => _tools.length;

  /// Whether any tools are registered.
  bool get isEmpty => _tools.isEmpty;

  /// Builds the MCP `tools/list` result list — one entry per
  /// registered, enabled tool with `name`, `description`,
  /// `inputSchema`, plus Vendure-style `annotations`
  /// (`readOnlyHint`/`destructiveHint`) for tools that declare their
  /// readonly/mutating classification via [McpReadonlyAwareTool]
  /// (issue #2046). Disabled tools are hidden, not listed.
  List<Map<String, dynamic>> toolDefinitions() {
    return _tools.values
        .where((t) => isEnabled(t.name))
        .map((t) {
          // McpReadonlyAwareTool is not a subtype of McpTool, so the
          // is-check cannot promote t — the cast is the promotion.
          final readonly = t is McpReadonlyAwareTool
              ? (t as McpReadonlyAwareTool).readonly
              : null;
          return {
            'name': t.name,
            'description': t.description,
            'inputSchema': t.inputSchema,
            if (readonly != null)
              'annotations': {
                'readOnlyHint': readonly,
                'destructiveHint': !readonly,
              },
          };
        })
        .toList(growable: false);
  }

  /// Clears all registered tools. Test-only — production callers
  /// should never invoke this.
  void clear() {
    _tools.clear();
  }
}
