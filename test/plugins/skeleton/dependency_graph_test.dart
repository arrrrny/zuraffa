/// Tests for DependencyGraph topological sort (U1-U4).
///
/// Behaviors traced to test-list.md:
///   U1: topological sort places every dependency before its dependent
///   U2: sorting a graph with no edges returns all nodes
///   U3: a cycle throws CycleException naming the bones in the cycle
///   U4: a self-dependency is reported as a cycle naming that bone
///
/// Pure-Dart: no I/O, no network, deterministic.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/models/dependency_graph.dart';

void main() {
  group('DependencyGraph.topologicalSort', () {
    test(
      'U1: topological sort places every dependency before its dependent',
      () {
        // A -> B -> C  (A depends on B, B depends on C)
        // Sort must return C before B, and B before A.
        final graph = DependencyGraph(
          nodes: {'a', 'b', 'c'},
          edges: {
            'a': ['b'],
            'b': ['c'],
          },
        );
        final order = graph.topologicalSort();
        expect(
          order.indexOf('c'),
          lessThan(order.indexOf('b')),
          reason: 'c must come before b',
        );
        expect(
          order.indexOf('b'),
          lessThan(order.indexOf('a')),
          reason: 'b must come before a',
        );
      },
    );

    test('U2: sorting a graph with no edges returns all nodes', () {
      final graph = DependencyGraph(nodes: {'x', 'y', 'z'}, edges: {});
      final order = graph.topologicalSort();
      expect(order, containsAll(['x', 'y', 'z']));
      expect(order, hasLength(3));
    });

    test('U3: a cycle throws CycleException naming the bones in the cycle', () {
      // A -> B -> A  (cycle between a and b)
      final graph = DependencyGraph(
        nodes: {'a', 'b'},
        edges: {
          'a': ['b'],
          'b': ['a'],
        },
      );
      expect(
        () => graph.topologicalSort(),
        throwsA(
          isA<CycleException>().having(
            (e) => e.cycleMembers,
            'cycleMembers',
            containsAll(['a', 'b']),
          ),
        ),
      );
    });

    test('U4: a self-dependency is reported as a cycle naming that bone', () {
      final graph = DependencyGraph(
        nodes: {'lonely'},
        edges: {
          'lonely': ['lonely'],
        },
      );
      expect(
        () => graph.topologicalSort(),
        throwsA(
          isA<CycleException>().having(
            (e) => e.cycleMembers,
            'cycleMembers',
            contains('lonely'),
          ),
        ),
      );
    });
  });
}
