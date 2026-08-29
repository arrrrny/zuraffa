/// FileGraph model (spec 043 data model).
library;

import 'slice_boundary.dart';
import 'slice_depth.dart';
import '../engine/import_graph_walker.dart';
import '../engine/package_resolver.dart';

/// A node in the project dependency graph.
class FileGraphNode {
  /// Creates a node.
  const FileGraphNode({
    required this.filePath,
    required this.imports,
    required this.diTypes,
    required this.companions,
  });

  /// Absolute path of the Dart file.
  final String filePath;

  /// Resolved absolute paths of imported local files (barrel imports are
  /// already expanded to the concrete targets).
  final List<String> imports;

  /// Types resolved via `getIt<T>()` in this file.
  final List<String> diTypes;

  /// Companion file paths (`.g.dart`, `.freezed.dart`).
  final List<String> companions;
}

/// The sliced project's file dependency graph.
class FileGraph {
  /// Creates the graph.
  const FileGraph({
    required this.nodes,
    required this.packageName,
    required this.projectRoot,
    required this.boundaries,
    required this.edgeFiles,
  });

  /// Included file path to node.
  final Map<String, FileGraphNode> nodes;

  /// The project's package name.
  final String packageName;

  /// The project root directory.
  final String projectRoot;

  /// Interfaces at the traversal edge.
  final List<SliceBoundary> boundaries;

  /// Excluded-but-referenced files (absolute paths).
  final Set<String> edgeFiles;

  /// All files reachable from [filePath] within the included nodes (U20's
  /// closure over the recorded graph).
  Set<String> getTransitiveClosure(String filePath) {
    final closure = <String>{};
    final queue = <String>[filePath];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!closure.add(current)) continue;
      final node = nodes[current];
      if (node == null) continue;
      queue.addAll(node.imports.where(nodes.containsKey));
    }
    return closure;
  }

  /// Boundaries recorded during the build.
  List<SliceBoundary> getBoundaries() => boundaries;

  /// Builds the subgraph reachable from [entries] at [depth].
  ///
  /// Convenience facade over [ImportGraphWalker]; the walker is the real
  /// builder.
  static Future<FileGraph> buildFromEntries({
    required List<String> entries,
    required String projectRoot,
    required SliceDepth depth,
  }) async {
    final resolver = await PackageResolver.load(projectRoot);
    final walker = ImportGraphWalker();
    final result = await walker.walk(
      entries: entries,
      projectRoot: projectRoot,
      resolver: resolver,
      depth: depth,
    );
    return result.graph;
  }
}

/// Architecture layer of a lib-relative path (spec 043 depth model,
/// data-model.md SliceDepth table).
///
/// Layers: `view` (page view/controller/state files), `presenter`,
/// `presentation_shared` (widgets and shared UI), `domain`, `data`, `di`,
/// and `other` for cross-cutting files (core/, config/, main.dart).
String classifyLayer(String relativePath) {
  final normalized = relativePath.replaceAll('\\', '/');
  if (normalized.startsWith('lib/src/presentation/pages/')) {
    return normalized.contains('presenter') ? 'presenter' : 'view';
  }
  if (normalized.startsWith('lib/src/presentation/')) {
    return 'presentation_shared';
  }
  if (normalized.startsWith('lib/src/domain/')) return 'domain';
  if (normalized.startsWith('lib/src/data/')) return 'data';
  if (normalized.startsWith('lib/src/di/')) return 'di';
  return 'other';
}

/// Whether [layer] is included when cutting at [depth] (FR-002).
bool layerAllowedAtDepth(String layer, SliceDepth depth) {
  return switch (depth) {
    SliceDepth.view => switch (layer) {
        'view' || 'presentation_shared' || 'other' => true,
        _ => false,
      },
    SliceDepth.presentation => switch (layer) {
        'view' || 'presentation_shared' || 'other' || 'presenter' => true,
        _ => false,
      },
    SliceDepth.feature => switch (layer) {
        'view' ||
        'presentation_shared' ||
        'other' ||
        'presenter' ||
        'domain' ||
        'di' => true,
        _ => false,
      },
    SliceDepth.full => true,
  };
}
