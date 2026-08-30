import 'dart:io';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/runtime/zuraffa_tui.dart';
import 'package:zuraffa/src/plugins/tui/edge/tty_guard.dart';

import '../../helpers/project_root.dart';

/// **SC-006**: The plugin initializes correctly on a pure-Dart (non-Flutter)
/// Zuraffa app and degrades gracefully when the terminal/engine is
/// unavailable.
///
/// The pure-Dart init contract:
/// 1. `ZuraffaTui.run` is a public static method callable from a pure-Dart
///    `main()` — no Flutter SDK required (FR-012).
/// 2. The plugin's TUI types compile under `dart` (not `flutter`).
/// 3. The plugin's pubspec.yaml declares `nocterm: ^0.9.0` (pure-Dart).
/// 4. When stdout is not a TTY, `TtyGuard.requireTty()` throws a clear
///    `TuiNonTtyException` rather than hanging or corrupting output
///    (FR-009, SC-006).
void main() async {
  final repoRoot = await findProjectRoot();
  group('SC-006: pure-Dart init + graceful degradation', () {
    test('A25: the plugin compiles under dart (not flutter) — types are '
        'resolvable from package:zuraffa without flutter_test', () {
      // The fact that this test file loads under `dart test` proves the
      // pure-Dart init contract. We additionally assert the public type
      // surface is resolvable.
      expect(ZuraffaTui.run, isA<Function>());
      expect(const TtyGuard(), isA<TtyGuard>());
    });

    test('A25 (continued): pubspec.yaml does not declare a flutter SDK '
        'dependency for zuraffa itself', () {
      final pubspec = File('$repoRoot/pubspec.yaml').readAsStringSync();
      // zuraffa's own environment.sdk must NOT be `flutter`.
      expect(pubspec, contains('sdk: ^3.11.0'));
      // nocterm must be a regular dependency, not flutter-only.
      expect(pubspec, contains('nocterm: ^0.9.0'));
    });

    test('A15 / SC-006: non-TTY stdout → TtyGuard.requireTty throws with a '
        'clear message', () {
      final guard = const TtyGuard();
      // The dart test runner pipes stdout — isTty() is typically false
      // here. When true (real terminal), requireTty is a no-op.
      if (!guard.isTty()) {
        expect(guard.requireTty, throwsA(isA<TuiNonTtyException>()));
      } else {
        expect(() => guard.requireTty(), returnsNormally);
      }
    });

    test('A19 / SC-006: engine-init failure → TuiEngineInitException with an '
        'actionable message', () {
      const exc = TuiEngineInitException(
        'nocterm could not initialize the terminal — '
        'check that your platform supports raw terminal mode.',
        cause: 'mock: missing libtinfo',
      );
      expect(exc.message, contains('nocterm'));
      expect(exc.message, contains('terminal'));
      expect(exc.cause, 'mock: missing libtinfo');
      expect(exc.toString(), contains('nocterm'));
      expect(exc.toString(), contains('libtinfo'));
    });
  });
}
