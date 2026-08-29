/// Resolves inter-bone dependencies by scanning feature specs.
///
/// A feature "references" another's entity when its spec mentions an entity
/// name it does not itself declare in `## Key Entities`. The resolver scans
/// all feature specs in a directory, extracts each feature's declared entities
/// via [SpecReader], and matches cross-feature references.
library;

import '../models/bone.dart';
import '../models/dependency_graph.dart';

/// Describes one feature's parsed spec for dependency resolution.
class FeatureSpec {
  /// Creates a [FeatureSpec].
  const FeatureSpec({
    required this.slug,
    required this.declaredEntities,
    required this.specContent,
  });

  /// Kebab-case feature slug (directory name).
  final String slug;

  /// Entity names declared in `## Key Entities`.
  final List<String> declaredEntities;

  /// Full text content of the spec (for body scanning).
  final String specContent;
}

/// Thrown when dependency resolution detects a conflict or missing entity.
class DependencyResolutionError implements Exception {
  /// Creates a [DependencyResolutionError].
  const DependencyResolutionError(this.message);

  /// Human-readable error message.
  final String message;

  @override
  String toString() => 'DependencyResolutionError: $message';
}

/// Resolves inter-bone dependencies from feature specs.
class DependencyResolver {
  /// Creates a [DependencyResolver] from pre-parsed [features].
  DependencyResolver({required this.features});

  /// Map of feature slug → parsed feature spec.
  final Map<String, FeatureSpec> features;

  /// Resolves dependencies for [targetSlug].
  ///
  /// Returns the list of [BoneDependency] edges for the target bone.
  ///
  /// Throws [DependencyResolutionError] on entity conflicts or missing entities.
  /// Throws [CycleException] on circular dependencies.
  List<BoneDependency> resolve(String targetSlug) {
    // 1. Build a global entity → feature map for conflict detection.
    final entityToFeature = <String, String>{};
    for (final entry in features.entries) {
      for (final entity in entry.value.declaredEntities) {
        final prev = entityToFeature[entity];
        if (prev != null && prev != entry.key) {
          throw DependencyResolutionError(
            'Entity "$entity" is defined in both "$prev" and "${entry.key}". '
            'conflict: definitions must be reconciled before generating.',
          );
        }
        entityToFeature[entity] = entry.key;
      }
    }

    // 2. Build the dependency graph to detect cycles.
    final edges = <String, List<String>>{};
    for (final entry in features.entries) {
      final deps = _findReferences(entry.value, entityToFeature);
      edges[entry.key] = deps.map((d) => d.bone).toList();
    }

    final graph = DependencyGraph(
      nodes: features.keys.toSet(),
      edges: edges,
    );
    // Throws CycleException if cyclic.
    graph.topologicalSort();

    // 3. Return dependencies for the target feature.
    return _findReferences(features[targetSlug]!, entityToFeature);
  }

  /// Finds cross-feature entity references for [feature].
  ///
  /// A "reference" is a declared entity name from another feature that appears
  /// in [feature]'s spec body (outside `## Key Entities`).
  ///
  /// Also detects references to entities not declared by any known feature and
  /// throws [DependencyResolutionError] (edge case: missing entity).
  List<BoneDependency> _findReferences(
    FeatureSpec feature,
    Map<String, String> entityToFeature,
  ) {
    // Build the set of locally declared entities.
    final localEntities = feature.declaredEntities.toSet();

    // Scan the spec body for mentions of declared entity names.
    // Strip the `## Key Entities` section to avoid matching declarations.
    final body = _stripKeyEntitiesSection(feature.specContent);

    // Collect referenced entity → source feature mapping.
    final refMap = <String, String>{};
    for (final entry in entityToFeature.entries) {
      final entityName = entry.key;
      final sourceFeature = entry.value;

      // Skip entities declared by this feature.
      if (localEntities.contains(entityName)) continue;

      // Check if the entity name appears in the spec body.
      // Use word-boundary matching to avoid substring false positives.
      if (RegExp('\\b$entityName\\b').hasMatch(body)) {
        refMap[entityName] = sourceFeature;
      }
    }

    // Detect references to entities not declared by any known feature.
    // Scan for PascalCase words in non-heading lines that look like entity
    // names but aren't in the global entity map.
    final allKnownEntities = {
      ...localEntities,
      ...entityToFeature.keys,
    };
    // Matches: Product, Beta, CartItem, OrderItem, etc.
    // Excludes: plurals (ending in 's') and words from heading lines.
    final entityNamePattern = RegExp(
      r'\b([A-Z][a-z]+(?:[A-Z][a-z]+)*)\b',
    );
    // Only scan non-heading lines (skip lines starting with '#').
    final bodyLines = body.split('\n');
    for (final line in bodyLines) {
      if (line.trimLeft().startsWith('#')) continue;
      for (final match in entityNamePattern.allMatches(line)) {
        final word = match.group(1)!;
        // Entity names don't end with lowercase 's' (plural forms are prose).
        if (word.endsWith('s')) continue;
        if (!allKnownEntities.contains(word)) {
          throw DependencyResolutionError(
            'Entity "$word" is referenced in "${feature.slug}" but is not '
            'declared by any known feature. '
            'missing: entity not defined in any feature spec.',
          );
        }
      }
    }

    if (refMap.isEmpty) return const [];

    // Group by source feature.
    final depMap = <String, List<String>>{};
    for (final entry in refMap.entries) {
      depMap.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    return depMap.entries
        .map((e) => BoneDependency(bone: e.key, entities: e.value))
        .toList();
  }

  /// Strips the `## Key Entities` section from spec content.
  ///
  /// This prevents entity declarations from being counted as references.
  /// Exits the section at the next heading or after the entity list ends
  /// (blank line after the last `- **Name**` entry).
  String _stripKeyEntitiesSection(String content) {
    final lines = content.split('\n');
    final result = <String>[];
    var inKeyEntities = false;
    var lastEntityLine = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (RegExp(r'^#{1,6}\s+key entities\s*$', caseSensitive: false)
          .hasMatch(trimmed)) {
        continue;
      }
      if (inKeyEntities) {
        // Exit at any heading.
        if (trimmed.startsWith('#')) {
          inKeyEntities = false;
        }
        // Exit at a blank line after entity entries.
        if (lastEntityLine && trimmed.isEmpty) {
          inKeyEntities = false;
        }
        lastEntityLine =
            inKeyEntities && RegExp(r'^-?\s*\*\*').hasMatch(trimmed);
      }
      if (!inKeyEntities) {
        result.add(line);
      }
    }

    return result.join('\n');
  }
}
