import 'policy_hook.dart';

/// Registry mapping tool name patterns to [RiskLevel]s (FR-001).
///
/// Most-restrictive-wins on conflict (FR-001 edge case). Falls back to
/// the tool's own risk metadata (passed in by the agent core) when the
/// registry has no entry (FR-012).
class PermissionRegistry {
  PermissionRegistry({Map<String, RiskLevel>? entries}) {
    if (entries != null) _entries.addAll(entries);
  }

  final Map<String, RiskLevel> _entries = <String, RiskLevel>{};

  /// Registers a tool name → risk level mapping. If [toolName] is already
  /// registered, the most-restrictive level wins.
  void register(String toolName, RiskLevel level) {
    final existing = _entries[toolName];
    _entries[toolName] = existing == null
        ? level
        : existing.mostRestrictive(level);
  }

  /// Looks up the risk level for [toolName]. Falls back to [fallback] (the
  /// tool's self-declared risk metadata) when no entry is registered.
  /// Defaults to [RiskLevel.safe] if neither is present.
  RiskLevel lookup(String toolName, {RiskLevel? fallback}) {
    final registered = _entries[toolName];
    if (registered != null) return registered;
    return fallback ?? RiskLevel.safe;
  }

  /// Whether [toolName] has a registered risk level.
  bool has(String toolName) => _entries.containsKey(toolName);

  /// Number of registered entries.
  int get size => _entries.length;
}
