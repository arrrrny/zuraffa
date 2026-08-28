import 'mcp_tool_provider.dart';

/// Thrown when two tool sources register the same canonical name (FR-012).
class NamespaceCollisionException implements Exception {
  NamespaceCollisionException(this.canonicalName, this.existing, this.incoming);

  /// The canonical name (`"$namespace.$toolName"`) that collided.
  final String canonicalName;

  /// The source that already registered the tool (e.g. `'spi:device'`).
  final String existing;

  /// The source that attempted to register (e.g. `'remote:sse'`).
  final String incoming;

  @override
  String toString() =>
      'NamespaceCollisionException: $canonicalName already registered by '
      '"$existing" — refused incoming from "$incoming" (FR-012)';
}

/// Flat, collision-safe registry of all available MCP tools from all
/// sources (FR-003, FR-012).
///
/// Tools are keyed by `"$namespace.$toolName"`. The first source to
/// register a canonical name wins; later attempts throw
/// [NamespaceCollisionException].
class McpToolRegistry {
  McpToolRegistry();

  final Map<String, McpTool> _tools = <String, McpTool>{};
  final Map<String, String> _sources = <String, String>{};

  /// Canonical key for a (namespace, toolName) pair.
  static String canonicalOf(String namespace, String toolName) =>
      '$namespace.$toolName';

  /// Registers [tool] under [namespace]. Throws on collision (FR-012).
  /// [source] is a diagnostic label like `'spi:device'` or `'remote:sse'`.
  void register({
    required String namespace,
    required McpTool tool,
    required String source,
  }) {
    final canonical = canonicalOf(namespace, tool.name);
    if (_tools.containsKey(canonical)) {
      throw NamespaceCollisionException(
        canonical,
        _sources[canonical]!,
        source,
      );
    }
    _tools[canonical] = tool;
    _sources[canonical] = source;
  }

  /// Looks up a tool by canonical key. Returns null if not registered.
  McpTool? lookup(String canonical) => _tools[canonical];

  /// All registered tools (canonical key → tool).
  Map<String, McpTool> get all => Map<String, McpTool>.unmodifiable(_tools);

  /// All registered canonical names.
  Iterable<String> get canonicalNames => _tools.keys;

  /// Number of registered tools.
  int get size => _tools.length;

  /// Tool count per namespace (used by [KernelStatus], FR-011).
  Map<String, int> get toolCountPerNamespace {
    final out = <String, int>{};
    for (final canonical in _tools.keys) {
      final ns = canonical.split('.').first;
      out[ns] = (out[ns] ?? 0) + 1;
    }
    return out;
  }

  /// Source label per canonical name (diagnostic).
  Map<String, String> get sources => Map<String, String>.unmodifiable(_sources);
}
