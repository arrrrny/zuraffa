/// Risk tier for a generated MCP tool (FR-007).
///
/// `safe` is the default for every generated tool. `admin` is assigned
/// to tools whose originating UseCase was annotated with the
/// internal-only marker `@AgentInternal` (a Zorphy concern; the
/// AgentPlugin only reads the annotation, it does not define it).
///
/// Stored as a plain `String` so emitted manifest code can use the
/// literal string directly without an import on this enum (which would
/// couple the generated app to the zuraffa codegen package).
class ToolManifestEntry {
  /// Canonical tool name, e.g. `app.listing.compose`.
  final String name;

  /// Owning entity, snake_case, e.g. `listing`.
  final String entity;

  /// Risk tier — `'safe'` or `'admin'`.
  final String riskTier;

  const ToolManifestEntry({
    required this.name,
    required this.entity,
    required this.riskTier,
  });

  @override
  String toString() =>
      'ToolManifestEntry($name, entity=$entity, tier=$riskTier)';

  @override
  bool operator ==(Object other) =>
      other is ToolManifestEntry &&
      name == other.name &&
      entity == other.entity &&
      riskTier == other.riskTier;

  @override
  int get hashCode => Object.hash(name, entity, riskTier);
}

/// Default namespace applied to every generated tool name when no
/// override is configured. Prevents cross-project tool name collisions
/// (e.g. two different zuraffa apps both shipping a `listing.compose`
/// tool would clash at the agent runtime layer without a namespace).
const String kDefaultAgentToolNamespace = 'app';
