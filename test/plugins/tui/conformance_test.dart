import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/theme/theme.dart';
import 'package:zuraffa/src/plugins/tui/input/key_bindings.dart';
import 'package:zuraffa/src/plugins/tui/runtime/zuraffa_tui.dart';
import 'package:zuraffa/src/plugins/tui/core/component.dart';
import 'package:zuraffa/src/plugins/tui/di/tui_di_resolver.dart';

/// SC-003 conformance test — two independently built Zuraffa TUIs each pass
/// the same documented conformance test:
///
/// 1. Each TUI uses the shared theme vocabulary (colors, emphasis, spacing,
///    status semantics) from [ZuraffaTuiTheme.defaultTheme].
/// 2. Each TUI uses the canonical keyboard defaults from [KeyBindings.defaults]
///    (FR-006).
/// 3. One configured override (plugin or app) takes precedence while
///    unoverridden keys retain their defaults.
///
/// Both TUIs are simulated by constructing the public types directly; the
/// runtime is not booted (the test exercises the type-level contract, not
/// the live terminal — see [ZuraffaTuiTest] for the boot smoke).
void main() {
  group('SC-003: shared conformance test', () {
    // Two independently built TUIs — modeled as separate "app" instances.
    // In a real deployment these would be two separate `zuraffa` apps; here
    // they're two pairs of (theme, keyBindings) constructed the same way the
    // `zuraffa_tui_app` and `another_zuraffa_tui_app` packages would.
    final tuiA = (
      theme: ZuraffaTuiTheme.defaultTheme(),
      keys: KeyBindings.defaults(),
    );
    final tuiB = (
      theme: ZuraffaTuiTheme.defaultTheme(),
      keys: KeyBindings.defaults(),
    );

    test(
      'A24 (1): both TUIs use the same shared theme vocabulary',
      () {
        // Same theme instance reference would be too strict — they may be
        // constructed independently. They must be equal by value.
        expect(tuiA.theme, equals(tuiB.theme));

        // The vocabulary is complete: colors, emphasis, spacing, status.
        for (final theme in [tuiA.theme, tuiB.theme]) {
          expect(theme.primary, isA<TuiColor>());
          expect(theme.secondary, isA<TuiColor>());
          expect(theme.accent, isA<TuiColor>());
          expect(theme.background, isA<TuiColor>());
          expect(theme.emphasis.high, isA<TuiColor>());
          expect(theme.emphasis.medium, isA<TuiColor>());
          expect(theme.emphasis.low, isA<TuiColor>());
          expect(theme.emphasis.muted, isA<TuiColor>());
          expect(theme.spacing.xs, isA<int>());
          expect(theme.spacing.md, isA<int>());
          expect(theme.spacing.lg, isA<int>());
          expect(theme.status.success, isA<TuiColor>());
          expect(theme.status.warning, isA<TuiColor>());
          expect(theme.status.error, isA<TuiColor>());
          expect(theme.status.info, isA<TuiColor>());
        }
      },
    );

    test(
      'A24 (2): both TUIs use the canonical keyboard defaults (FR-006)',
      () {
        for (final keys in [tuiA.keys, tuiB.keys]) {
          // q and Ctrl+C quit.
          expect(keys.matches('q', KeyAction.quit), isTrue);
          expect(keys.matches('Ctrl+C', KeyAction.quit), isTrue);
          // Enter confirms.
          expect(keys.matches('Enter', KeyAction.confirm), isTrue);
          // Arrow keys navigate.
          expect(keys.matches('ArrowUp', KeyAction.navigateUp), isTrue);
          expect(keys.matches('ArrowDown', KeyAction.navigateDown), isTrue);
          expect(keys.matches('ArrowLeft', KeyAction.navigateLeft), isTrue);
          expect(keys.matches('ArrowRight', KeyAction.navigateRight), isTrue);
          // Tab / Shift+Tab cycle focus.
          expect(keys.matches('Tab', KeyAction.focusNext), isTrue);
          expect(keys.matches('Shift+Tab', KeyAction.focusPrevious), isTrue);
        }
      },
    );

    test(
      'A24 (3): one configured override takes precedence while '
      'unoverridden keys retain their defaults',
      () {
        // App A overrides quit to 'Q'; app B keeps defaults.
        final tuiAWithOverride = (
          theme: tuiA.theme,
          keys: KeyBindings.merge(
            appOverrides: {
              KeyAction.quit: {'Q'},
            },
          ),
        );
        final tuiBDefaults = tuiB;

        // App A's override takes precedence — Q quits, q no longer does.
        expect(tuiAWithOverride.keys.matches('Q', KeyAction.quit), isTrue);
        expect(tuiAWithOverride.keys.matches('q', KeyAction.quit), isFalse);

        // App B retains the default — q quits, Q doesn't.
        expect(tuiBDefaults.keys.matches('q', KeyAction.quit), isTrue);
        expect(tuiBDefaults.keys.matches('Q', KeyAction.quit), isFalse);

        // Both apps retain the unoverridden defaults — Enter confirms in
        // both, Tab cycles focus in both.
        expect(tuiAWithOverride.keys.matches('Enter', KeyAction.confirm), isTrue);
        expect(tuiBDefaults.keys.matches('Enter', KeyAction.confirm), isTrue);
        expect(tuiAWithOverride.keys.matches('Tab', KeyAction.focusNext), isTrue);
        expect(tuiBDefaults.keys.matches('Tab', KeyAction.focusNext), isTrue);

        // Same theme vocabulary — overriding keys doesn't affect the theme.
        expect(tuiAWithOverride.theme, equals(tuiBDefaults.theme));
      },
    );

    test(
      'A24 (4): the entry point signature is identical across both TUIs '
      '(static contract)',
      () {
        // Both apps call ZuraffaTui.run with the same signature.
        // (Type-level assertion — proves the public API surface is fixed.)
        final runRef = ZuraffaTui.run;
        expect(
          runRef,
          isA<
              Future<void> Function(
            Screen, {
            ZuraffaDIContainer? di,
            ZuraffaTuiTheme? theme,
            KeyBindings? keys,
          })>(),
        );
      },
    );
  });
}
