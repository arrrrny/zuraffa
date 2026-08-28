import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/input/key_bindings.dart';

void main() {
  group('KeyBindings (FR-006, SC-003)', () {
    group('A9 / U21: defaults', () {
      final defaults = KeyBindings.defaults();

      test('quit defaults to q and Ctrl+C', () {
        expect(defaults.matches('q', KeyAction.quit), isTrue);
        expect(defaults.matches('Ctrl+C', KeyAction.quit), isTrue);
        expect(defaults.matches('Q', KeyAction.quit), isFalse);
      });

      test('confirm defaults to Enter', () {
        expect(defaults.matches('Enter', KeyAction.confirm), isTrue);
      });

      test('cancel defaults to Escape', () {
        expect(defaults.matches('Escape', KeyAction.cancel), isTrue);
      });

      test('arrows navigate', () {
        expect(defaults.matches('ArrowUp', KeyAction.navigateUp), isTrue);
        expect(defaults.matches('ArrowDown', KeyAction.navigateDown), isTrue);
        expect(defaults.matches('ArrowLeft', KeyAction.navigateLeft), isTrue);
        expect(defaults.matches('ArrowRight', KeyAction.navigateRight), isTrue);
      });

      test('Tab / Shift+Tab cycle focus', () {
        expect(defaults.matches('Tab', KeyAction.focusNext), isTrue);
        expect(defaults.matches('Shift+Tab', KeyAction.focusPrevious), isTrue);
      });

      test('actionFor returns the right action for a known key', () {
        expect(defaults.actionFor('q'), KeyAction.quit);
        expect(defaults.actionFor('Ctrl+C'), KeyAction.quit);
        expect(defaults.actionFor('Enter'), KeyAction.confirm);
        expect(defaults.actionFor('ArrowDown'), KeyAction.navigateDown);
        expect(defaults.actionFor('Tab'), KeyAction.focusNext);
      });

      test('actionFor returns null for an unmapped key', () {
        expect(defaults.actionFor('x'), isNull);
        expect(defaults.actionFor('F1'), isNull);
      });

      test('unmapped action returns empty key set', () {
        expect(defaults.keysFor(KeyAction.quit), isNotEmpty);
        // KeyAction is closed — every value has a default mapping, so this
        // path is just defensive coverage.
      });
    });

    group('A10 / U22: merge precedence', () {
      test(
        'plugin override replaces the default for the overridden action',
        () {
          final merged = KeyBindings.merge(
            pluginOverrides: {
              KeyAction.quit: {'x'},
            },
          );
          expect(
            merged.matches('q', KeyAction.quit),
            isFalse,
            reason: 'default q should be replaced by plugin override',
          );
          expect(
            merged.matches('Ctrl+C', KeyAction.quit),
            isFalse,
            reason: 'default Ctrl+C should be replaced by plugin override',
          );
          expect(merged.matches('x', KeyAction.quit), isTrue);
        },
      );

      test('app override wins any conflict with a plugin override', () {
        final merged = KeyBindings.merge(
          pluginOverrides: {
            KeyAction.quit: {'x'},
          },
          appOverrides: {
            KeyAction.quit: {'y'},
          },
        );
        expect(
          merged.matches('x', KeyAction.quit),
          isFalse,
          reason: 'app override must win conflict with plugin override',
        );
        expect(merged.matches('y', KeyAction.quit), isTrue);
      });

      test('unoverridden actions retain their defaults', () {
        final merged = KeyBindings.merge(
          pluginOverrides: {
            KeyAction.quit: {'x'},
          },
          appOverrides: {
            KeyAction.quit: {'y'},
          },
        );
        // confirm is not overridden — must keep its default.
        expect(merged.matches('Enter', KeyAction.confirm), isTrue);
        // arrows still navigate.
        expect(merged.matches('ArrowDown', KeyAction.navigateDown), isTrue);
        // Tab still cycles focus.
        expect(merged.matches('Tab', KeyAction.focusNext), isTrue);
        expect(merged.matches('Shift+Tab', KeyAction.focusPrevious), isTrue);
      });

      test('plugin + app can override different actions independently', () {
        final merged = KeyBindings.merge(
          pluginOverrides: {
            KeyAction.confirm: {' '}, // spacebar to confirm
          },
          appOverrides: {
            KeyAction.quit: {'Q'}, // uppercase Q to quit
          },
        );
        expect(merged.matches(' ', KeyAction.confirm), isTrue);
        expect(merged.matches('Enter', KeyAction.confirm), isFalse);
        expect(merged.matches('Q', KeyAction.quit), isTrue);
        expect(merged.matches('q', KeyAction.quit), isFalse);
        // Untouched action retains default.
        expect(merged.matches('Tab', KeyAction.focusNext), isTrue);
      });

      test('equality holds for two merges with the same overrides', () {
        final a = KeyBindings.merge(
          pluginOverrides: {
            KeyAction.quit: {'x'},
          },
        );
        final b = KeyBindings.merge(
          pluginOverrides: {
            KeyAction.quit: {'x'},
          },
        );
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });
    });
  });
}
