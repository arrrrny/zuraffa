import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/context/context_store.dart';

void main() {
  group('ContextStore', () {
    test('stores and retrieves values by type', () {
      final store = ContextStore();
      store.set('count', 2);
      store.set('name', 'test');

      expect(store.get<int>('count'), equals(2));
      expect(store.get<String>('name'), equals('test'));
      expect(store.has('count'), isTrue);
    });

    test('returns default value when missing', () {
      final store = ContextStore();
      final value = store.get<int>('missing', defaultValue: () => 5);
      expect(value, equals(5));
    });

    test('throws for missing key without default', () {
      final store = ContextStore();
      expect(() => store.get<int>('missing'), throwsStateError);
    });

    test('throws for type mismatch', () {
      final store = ContextStore();
      store.set('count', 2);
      expect(() => store.get<String>('count'), throwsStateError);
    });

    test('getOrNull returns null for missing or mismatch', () {
      final store = ContextStore();
      store.set('count', 2);
      expect(store.getOrNull<String>('count'), isNull);
      expect(store.getOrNull<int>('missing'), isNull);
    });

    test('notifies listeners on set and remove', () {
      final store = ContextStore();
      var hits = 0;
      void listener() {
        hits += 1;
      }

      store.addListener('value', listener);
      store.set('value', 1);
      store.remove('value');
      store.removeListener('value', listener);
      store.set('value', 2);

      expect(hits, equals(2));
    });

    test('clear resets data and listeners', () {
      final store = ContextStore();
      var hits = 0;
      store.addListener('value', () {
        hits += 1;
      });
      store.set('value', 1);
      store.clear();
      store.set('value', 2);

      expect(store.has('value'), isTrue);
      expect(hits, equals(1));
    });
  });
}
