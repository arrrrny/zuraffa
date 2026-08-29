/// Canonical namespacing for generated MCP tools and collision detection
/// (FR-009).
///
/// Tool names are namespaced as `{namespace}.{entity}.{verb}` to prevent
/// collisions across entities and projects. The first attempt to register
/// a duplicate canonical name in a single generation pass throws
/// [ToolNameConflictException]; the plugin never silently overwrites.
library;

/// Thrown when two UseCases from different entities produce the same
/// canonical tool name in the same generation pass (FR-009).
class ToolNameConflictException implements Exception {
  const ToolNameConflictException(
    this.canonicalName,
    this.existingEntity,
    this.incomingEntity,
  );

  /// The canonical name (`{namespace}.{entity}.{verb}`) that collided.
  final String canonicalName;

  /// The entity that first registered this canonical name.
  final String existingEntity;

  /// The entity that attempted to register a duplicate.
  final String incomingEntity;

  @override
  String toString() =>
      'ToolNameConflictException: canonical name "$canonicalName" is '
      'already registered for entity "$existingEntity" — refusing to '
      'overwrite with entity "$incomingEntity" (FR-009)';
}

/// Computes the canonical tool name for a (namespace, entity, verb) triple.
///
/// Returns `{namespace}.{entitySnake}.{verb}`. The verb is the lowercased
/// first word of the UseCase class name (e.g. `CreateListingUseCase` →
/// `create`; `GetListingListUseCase` → `get`).
String canonicalToolName({
  required String namespace,
  required String entitySnake,
  required String verb,
}) {
  return '$namespace.$entitySnake.$verb';
}

/// Accumulates canonical tool names across a single generation pass and
/// fails fast on the first duplicate.
class CollisionDetector {
  final Map<String, String> _registered = {};

  /// Registers [canonical] for [entity]. Throws [ToolNameConflictException]
  /// if [canonical] was already registered for a DIFFERENT entity.
  ///
  /// Re-registering the same canonical for the SAME entity (idempotent
  /// regeneration) is a no-op.
  void register({required String canonical, required String entity}) {
    final existing = _registered[canonical];
    if (existing == null) {
      _registered[canonical] = entity;
      return;
    }
    if (existing == entity) {
      // Idempotent re-registration: no-op.
      return;
    }
    throw ToolNameConflictException(canonical, existing, entity);
  }

  /// Whether [canonical] has been registered in this pass.
  bool contains(String canonical) => _registered.containsKey(canonical);

  /// Number of distinct canonicals registered.
  int get size => _registered.length;
}
