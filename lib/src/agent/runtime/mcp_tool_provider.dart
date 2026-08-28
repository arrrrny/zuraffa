/// SPI interface implemented by device packages to declare their available
/// MCP tools under a namespace (FR-001, FR-002).
///
/// Implementations are discovered via DI/engine registration by
/// [AgentRuntimePlugin]. Each provider contributes zero or more tools to
/// the assembled [McpToolRegistry].
abstract class McpToolProvider {
  /// Stable, unique namespace for this provider's tools. Used as the
  /// prefix in the registry's flat `"$namespace.$toolName"` keys.
  String get namespace;

  /// Builds the tools contributed by this provider, given the
  /// [McpToolContext] (DI accessor). May return an empty list.
  ///
  /// Implementations MUST be idempotent: building tools twice for the
  /// same context returns equivalent tool lists.
  List<McpTool> buildTools(McpToolContext ctx);
}

/// A tool registered with the [McpToolRegistry] (FR-001).
abstract class McpTool {
  /// Tool name (without the namespace prefix).
  String get name;

  /// Human-readable description (consumed by the system prompt composer,
  /// FR-006).
  String get description;

  /// JSON-schema-like input description (consumed by the system prompt
  /// composer, FR-006).
  Map<String, Object?> get inputSchema;

  /// Invokes the tool. Returns the result payload.
  Future<Object?> invoke(Map<String, Object?> args);

  /// Manifest used by [SystemPromptComposer] (FR-006).
  Map<String, Object?> get manifest => <String, Object?>{
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// Context passed to [McpToolProvider.buildTools] (FR-001). Acts as a
/// DI accessor so providers can resolve dependencies they were registered
/// with.
class McpToolContext {
  McpToolContext({this.resolve});

  /// Resolver function — returns the registered instance for [key] or
  /// null. Real DI containers wire this; tests can pass a stub.
  final Object? Function(String key)? resolve;

  /// Looks up a dependency by [key]. Returns null if not registered.
  Object? dependency(String key) => resolve?.call(key);
}
