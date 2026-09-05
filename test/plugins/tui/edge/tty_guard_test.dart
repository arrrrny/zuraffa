import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/edge/tty_guard.dart';
import 'package:zuraffa/src/plugins/tui/runtime/zuraffa_tui.dart';
import 'package:zuraffa/src/plugins/tui/core/component.dart';
import 'package:zuraffa/src/plugins/tui/di/tui_di_resolver.dart';
import 'package:zuraffa/src/plugins/tui/theme/theme.dart';
import 'package:zuraffa/src/plugins/tui/input/key_bindings.dart';

void main() {
  group('TtyGuard (FR-009, SC-006)', () {
    test(
      'A15 / U31: isTty() returns a bool consistent with stdout.hasTerminal',
      () {
        final guard = const TtyGuard();
        expect(guard.isTty(), isA<bool>());
        // Whether it's true or false depends on the test runner's stdout,
        // which is typically piped → false here. We assert consistency only.
        expect(guard.isTty(), equals(stdout.hasTerminal));
      },
    );

    test('A15 / U31: requireTty() throws TuiNonTtyException with an actionable '
        'message when stdout is not a TTY', () {
      final guard = const TtyGuard();
      if (!guard.isTty()) {
        expect(
          guard.requireTty,
          throwsA(
            allOf(
              isA<TuiNonTtyException>(),
              predicate<TuiNonTtyException>(
                (e) =>
                    e.message.toLowerCase().contains('interactive') ||
                    e.message.toLowerCase().contains('tty'),
                'message must mention interactive/tty',
              ),
              predicate<TuiNonTtyException>(
                (e) => e.message.isNotEmpty,
                'message must not be empty',
              ),
            ),
          ),
        );
      } else {
        // If running under a real TTY, requireTty should be a no-op.
        expect(() => guard.requireTty(), returnsNormally);
      }
    });

    test('U33: TuiException family — TuiNonTtyException is a TuiException', () {
      const exc = TuiNonTtyException('nope');
      expect(exc, isA<TuiException>());
      expect(exc.message, 'nope');
      expect(exc.toString(), contains('nope'));
    });
  });

  group('ResizeHandler (FR-009)', () {
    test(
      'A16 / U32: relayResize invokes registered listeners with new dimensions',
      () {
        final handler = ResizeHandler();
        var receivedCols = 0;
        var receivedRows = 0;
        var callCount = 0;
        handler.addListener((cols, rows) {
          receivedCols = cols;
          receivedRows = rows;
          callCount++;
        });

        expect(handler.hasListeners, isTrue);

        handler.relayResize(120, 40);
        expect(receivedCols, 120);
        expect(receivedRows, 40);
        expect(callCount, 1);

        // A second resize to a very small terminal still relays.
        handler.relayResize(20, 5);
        expect(receivedCols, 20);
        expect(receivedRows, 5);
        expect(callCount, 2);
      },
    );

    test('removeListener stops further callbacks', () {
      final handler = ResizeHandler();
      var callCount = 0;
      void listener(int c, int r) => callCount++;

      handler.addListener(listener);
      handler.relayResize(80, 24);
      expect(callCount, 1);

      handler.removeListener(listener);
      handler.relayResize(100, 30);
      expect(
        callCount,
        1,
        reason: 'listener should not be called after removal',
      );
      expect(handler.hasListeners, isFalse);
    });
  });

  group('EngineInitFailure (FR-009, SC-006)', () {
    test(
      'A19 / U33: TuiEngineInitException is a TuiException with an actionable '
      'message and optional cause',
      () {
        const cause = 'missing libterm';
        const exc = TuiEngineInitException(
          'nocterm could not initialize the terminal — '
          'check that your platform supports raw terminal mode.',
          cause: cause,
        );
        expect(exc, isA<TuiException>());
        expect(exc.message, contains('nocterm'));
        expect(exc.message, contains('terminal'));
        expect(exc.cause, cause);
        expect(exc.toString(), contains('libterm'));
      },
    );
  });

  group('Minimal config (FR-009, FR-010)', () {
    test('A20: a TUI built from hand-composed screens alone runs (no entity '
        'scaffolding required)', () {
      // A "minimal config" TUI = a single hand-composed Screen. We assert
      // the public API does not require entity metadata: ZuraffaTui.run
      // accepts only a Screen + optional di/theme/keys, with no entity
      // manifest anywhere in the call signature.
      //
      // The actual end-to-end run is exercised in A25 (pure_dart_init_test)
      // and A1 (zuraffa_tui_test); here we assert the contract statically
      // so future API additions cannot silently introduce an entity
      // requirement.
      final run = ZuraffaTui.run;
      expect(
        run,
        isA<
          Future<void> Function(
            Screen, {
            ZuraffaDIContainer? di,
            ZuraffaTuiTheme? theme,
            KeyBindings? keys,
          })
        >(),
        reason:
            'ZuraffaTui.run must accept a hand-composed Screen '
            'with no entity metadata required',
      );
    });
  });
}
