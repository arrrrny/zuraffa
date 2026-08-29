/// Acyclic directed graph over bones with Kahn topological sort.
library;

/// Thrown when a topological sort encounters a cycle.
///
/// The [cycleMembers] list names the bones involved in the cycle.
class CycleException implements Exception {
  /// Creates a [CycleException] naming the [cycleMembers].
  const CycleException(this.cycleMembers);

  /// The bone slugs that form the cycle.
  final List<String> cycleMembers;

  @override
  String toString() => 'Cycle detected: ${cycleMembers.join(' → ')}';
}

/// Acyclic directed graph over bone slugs.
class DependencyGraph {
  /// Creates a [DependencyGraph] from [nodes] and [edges].
  ///
  /// [edges] maps a bone slug to the list of bones it depends on.
  const DependencyGraph({required this.nodes, this.edges = const {}});

  /// All bone slugs in the graph.
  final Set<String> nodes;

  /// Adjacency list: bone → bones it depends on.
  final Map<String, List<String>> edges;

  /// Returns a topological ordering (Kahn's algorithm).
  ///
  /// Throws [CycleException] if the graph contains a cycle.
  List<String> topologicalSort() {
    // edges[bone] = [deps] means bone depends on each dep in the list.
    // In Kahn's terms: dep → bone (dep comes before bone).
    final reverseEdges = <String, List<String>>{};
    final inDegree = <String, int>{for (final n in nodes) n: 0};

    for (final entry in edges.entries) {
      final bone = entry.key;
      for (final dep in entry.value) {
        reverseEdges.putIfAbsent(dep, () => []).add(bone);
        inDegree[bone] = inDegree[bone]! + 1;
      }
    }

    final queue = [
      for (final entry in inDegree.entries)
        if (entry.value == 0) entry.key,
    ]..sort();

    final result = <String>[];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      result.add(current);
      for (final dependent in reverseEdges[current] ?? <String>[]) {
        inDegree[dependent] = inDegree[dependent]! - 1;
        if (inDegree[dependent] == 0) {
          queue.add(dependent);
          queue.sort();
        }
      }
    }

    if (result.length != nodes.length) {
      final remaining = nodes.difference(result.toSet());
      throw CycleException(remaining.toList()..sort());
    }

    return result;
  }
}
