import 'package:test/test.dart';
import 'package:zuraffa/src/agent/plugin/tool_namespace.dart';

void main() {
  group('canonicalToolName + CollisionDetector — FR-009', () {
    test('canonicalToolName builds {namespace}.{entity}.{verb}', () {
      expect(
        canonicalToolName(
          namespace: 'app',
          entitySnake: 'listing',
          verb: 'create',
        ),
        'app.listing.create',
      );
    });

    test('CollisionDetector accepts first registration', () {
      final d = CollisionDetector();
      d.register(canonical: 'app.listing.create', entity: 'listing');
      expect(d.size, 1);
      expect(d.contains('app.listing.create'), isTrue);
    });

    test('CollisionDetector is idempotent on same-entity re-registration', () {
      final d = CollisionDetector();
      d.register(canonical: 'app.listing.create', entity: 'listing');
      d.register(canonical: 'app.listing.create', entity: 'listing');
      expect(d.size, 1);
    });

    test(
      'CollisionDetector throws ToolNameConflictException on duplicate across entities',
      () {
        final d = CollisionDetector();
        d.register(canonical: 'app.item.create', entity: 'item');
        expect(
          () => d.register(canonical: 'app.item.create', entity: 'order'),
          throwsA(isA<ToolNameConflictException>()),
        );
      },
    );

    test('ToolNameConflictException names both entities', () {
      const ex = ToolNameConflictException('app.item.create', 'item', 'order');
      expect(ex.canonicalName, 'app.item.create');
      expect(ex.existingEntity, 'item');
      expect(ex.incomingEntity, 'order');
      expect(ex.toString(), contains('app.item.create'));
      expect(ex.toString(), contains('item'));
      expect(ex.toString(), contains('order'));
      expect(ex.toString(), contains('FR-009'));
    });

    test(
      'same verb across DIFFERENT entities does NOT collide (canonical differs)',
      () {
        final d = CollisionDetector();
        d.register(
          canonical: canonicalToolName(
            namespace: 'app',
            entitySnake: 'listing',
            verb: 'create',
          ),
          entity: 'listing',
        );
        // Different entity, same verb → different canonical → no throw.
        d.register(
          canonical: canonicalToolName(
            namespace: 'app',
            entitySnake: 'order',
            verb: 'create',
          ),
          entity: 'order',
        );
        expect(d.size, 2);
      },
    );
  });
}
