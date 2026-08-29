/// Tests for DependencyResolver (U23-U25).
///
/// Behaviors traced to test-list.md:
///   U23: cross-feature entity reference → dependency edge naming shared entity
///   U24: conflicting entity definitions across features → conflict error
///   U25: cycle across bones → CycleException naming member bones
///
/// Uses in-memory feature data; no filesystem I/O.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/generators/dependency_resolver.dart'
    show DependencyResolutionError, DependencyResolver, FeatureSpec;
import 'package:zuraffa/src/plugins/skeleton/models/dependency_graph.dart';

void main() {
  group('DependencyResolver.resolve', () {
    test('U23: cross-feature entity reference produces a dependency edge '
        'naming the shared entity', () {
      // Feature A declares Product.
      // Feature B declares Order and references Product in its body.
      // → B depends on A with shared entity Product.
      final resolver = DependencyResolver(
        features: {
          'feature-a': FeatureSpec(
            slug: 'feature-a',
            declaredEntities: ['Product'],
            specContent: '# Feature A\n\n## Key Entities\n\n- **Product**',
          ),
          'feature-b': FeatureSpec(
            slug: 'feature-b',
            declaredEntities: ['Order'],
            specContent:
                '# Feature B\n\n## Key Entities\n\n- **Order**\n\n'
                'Orders reference a Product from the catalog.',
          ),
        },
      );

      final deps = resolver.resolve('feature-b');
      expect(deps, hasLength(1));
      expect(deps.first.bone, equals('feature-a'));
      expect(deps.first.entities, contains('Product'));
    });

    test(
      'U23: multiple cross-feature references produce multiple dependency edges',
      () {
        final resolver = DependencyResolver(
          features: {
            'feature-a': FeatureSpec(
              slug: 'feature-a',
              declaredEntities: ['Product'],
              specContent: '# A\n\n## Key Entities\n\n- **Product**',
            ),
            'feature-c': FeatureSpec(
              slug: 'feature-c',
              declaredEntities: ['Review'],
              specContent: '# C\n\n## Key Entities\n\n- **Review**',
            ),
            'feature-b': FeatureSpec(
              slug: 'feature-b',
              declaredEntities: ['Order'],
              specContent:
                  '# B\n\n## Key Entities\n\n- **Order**\n\n'
                  'References Product and Review.',
            ),
          },
        );

        final deps = resolver.resolve('feature-b');
        expect(deps, hasLength(2));
        final depSlugs = deps.map((d) => d.bone).toSet();
        expect(depSlugs, containsAll(['feature-a', 'feature-c']));
        // Shared entities are Product and Review.
        final allEntities = deps.expand((d) => d.entities).toSet();
        expect(allEntities, containsAll(['Product', 'Review']));
      },
    );

    test('U24: conflicting definitions of the same entity name across features '
        'are refused', () {
      // Both feature-a and feature-b define Product.
      final resolver = DependencyResolver(
        features: {
          'feature-a': FeatureSpec(
            slug: 'feature-a',
            declaredEntities: ['Product'],
            specContent: '# A\n\n## Key Entities\n\n- **Product**',
          ),
          'feature-b': FeatureSpec(
            slug: 'feature-b',
            declaredEntities: ['Product'],
            specContent: '# B\n\n## Key Entities\n\n- **Product**',
          ),
        },
      );

      expect(
        () => resolver.resolve('feature-a'),
        throwsA(
          isA<DependencyResolutionError>().having(
            (e) => e.message,
            'message',
            allOf(contains('conflict'), contains('Product')),
          ),
        ),
      );
    });

    test('U25: cycle across bones is reported naming the member bones', () {
      // cycle-a declares Alpha and references Beta (from cycle-b).
      // cycle-b declares Beta and references Alpha (from cycle-a).
      final resolver = DependencyResolver(
        features: {
          'cycle-a': FeatureSpec(
            slug: 'cycle-a',
            declaredEntities: ['Alpha'],
            specContent:
                '# A\n\n## Key Entities\n\n- **Alpha**\n\n'
                'Alpha references Beta.',
          ),
          'cycle-b': FeatureSpec(
            slug: 'cycle-b',
            declaredEntities: ['Beta'],
            specContent:
                '# B\n\n## Key Entities\n\n- **Beta**\n\n'
                'Beta references Alpha.',
          ),
        },
      );

      expect(
        () => resolver.resolve('cycle-a'),
        throwsA(
          isA<CycleException>().having(
            (e) => e.cycleMembers,
            'cycleMembers',
            containsAll(['cycle-a', 'cycle-b']),
          ),
        ),
      );
    });

    test(
      'U23: feature with no cross-references returns empty dependencies',
      () {
        final resolver = DependencyResolver(
          features: {
            'standalone': FeatureSpec(
              slug: 'standalone',
              declaredEntities: ['Widget'],
              specContent:
                  '# Standalone\n\n## Key Entities\n\n- **Widget**\n\n'
                  'Widgets exist independently.',
            ),
          },
        );

        final deps = resolver.resolve('standalone');
        expect(deps, isEmpty);
      },
    );
  });
}
