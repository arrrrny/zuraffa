import 'mcp_tool_registry.dart';

/// Structured kernel status report (FR-011).
class KernelStatus {
  KernelStatus({
    required this.providers,
    required this.toolCountPerNamespace,
    required this.remoteServerHealth,
    required this.totalToolCount,
  });

  /// Registered SPI providers keyed by namespace.
  final Map<String, String> providers;

  /// Tool count per namespace (e.g. `{'device': 3, 'usecase': 5, 'remote:sse': 2}`).
  final Map<String, int> toolCountPerNamespace;

  /// Health check per remote MCP server (server-id → status string).
  final Map<String, String> remoteServerHealth;

  /// Total number of registered tools.
  final int totalToolCount;

  @override
  String toString() =>
      'KernelStatus(providers=$providers, '
      'toolCountPerNamespace=$toolCountPerNamespace, '
      'remoteServerHealth=$remoteServerHealth, totalToolCount=$totalToolCount)';
}

/// Builds [KernelStatus] from a [McpToolRegistry] + remote server map.
KernelStatus buildStatus(
  McpToolRegistry registry, {
  Map<String, String> providers = const <String, String>{},
  Map<String, String> remoteServerHealth = const <String, String>{},
}) {
  return KernelStatus(
    providers: providers,
    toolCountPerNamespace: registry.toolCountPerNamespace,
    remoteServerHealth: remoteServerHealth,
    totalToolCount: registry.size,
  );
}
