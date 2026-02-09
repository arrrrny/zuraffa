import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('ContextStore', () {
    test('stores and retrieves values', () {
      final store = ContextStore();
      store.set('key', 'value');
      expect(store.get<String>('key'), equals('value'));
    });

    test('returns default value when key missing', () {
      final store = ContextStore();
      expect(
        store.get<String>('missing', defaultValue: () => 'default'),
        equals('default'),
      );
    });

    test('throws when key missing without default', () {
      final store = ContextStore();
      expect(() => store.get<String>('missing'), throwsStateError);
    });

    test('notifies listeners on change', () {
      final store = ContextStore();
      var called = false;
      void listener() {
        called = true;
      }

      store.addListener('k', listener);
      store.set('k', 1);

      expect(called, isTrue);
    });

    test('supports type checking', () {
      final store = ContextStore();
      store.set('number', 42);
      expect(() => store.get<String>('number'), throwsStateError);
    });
  });
}
