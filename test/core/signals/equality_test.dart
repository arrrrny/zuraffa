import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

class _User {
  const _User(this.name);
  final String name;

  @override
  bool operator ==(Object other) => other is _User && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

void main() {
  group('US3 · Signal equality (identity-first default gate)', () {
    test('C1: re-assigning the identical instance never notifies', () {
      final user = const _User('ada');
      final signal = Signal<_User>(user);
      var notifications = 0;
      signal.listen((_) => notifications++); // eager: 1
      expect(notifications, 1);

      signal.value = user; // identical instance
      expect(notifications, 1, reason: 'identity fast-path: zero new notifications');
    });

    test('C1b: identical instance suppresses even a pathological == (gate order: identity first)', () {
      final instance = _BrokenEquals();
      final signal = Signal<_BrokenEquals>(instance);
      var notifications = 0;
      signal.listen((_) => notifications++);
      expect(notifications, 1);

      signal.value = instance; // identical, but == would say "changed"
      expect(notifications, 1, reason: 'identical() must short-circuit before ==');
    });

    test('C2: equal-by-== assignment never notifies', () {
      final signal = Signal<_User>(const _User('ada'));
      var notifications = 0;
      signal.listen((_) => notifications++);
      expect(notifications, 1);

      signal.value = const _User('ada'); // different instance, equal by ==
      expect(notifications, 1, reason: 'structural gate still suppresses equal writes');
    });

    test('C3: custom equals function is preserved unchanged', () {
      // Custom gate: only compare by first character.
      final signal = Signal<String>('alpha', equals: (a, b) => a[0] == b[0]);
      var notifications = 0;
      signal.listen((_) => notifications++);
      expect(notifications, 1);

      signal.value = 'ant'; // custom equals says equal → no notify
      expect(notifications, 1);

      signal.value = 'beta'; // custom equals says different → notify
      expect(notifications, 2);
    });

    test('C4: a different value still notifies', () {
      final signal = Signal<int>(1);
      var notifications = 0;
      signal.listen((_) => notifications++);
      expect(notifications, 1);

      signal.value = 2;
      expect(notifications, 2);
      expect(signal.value, 2);
    });
  });
}

/// Pathological equality: always reports "changed", even for itself.
class _BrokenEquals {
  @override
  bool operator ==(Object other) => false;
  @override
  int get hashCode => 1;
}
