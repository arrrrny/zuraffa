import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'failure.dart';
import 'failure_reporter_registry.dart';

/// The central uncaught-error funnel for the Zuraffa family.
///
/// Every uncaught error — a widget-build failure surfaced by
/// `FlutterError.onError`, an uncaught async error routed through
/// `PlatformDispatcher.instance.onError`, a fire-and-forget future, or an
/// isolate failure — funnels through [UncaughtErrorFunnel.captureUncaught],
/// which turns it into:
///
/// 1. a `SEVERE` record on `Logger.root` (so every log exporter, including
///    `OtelLogExporter`, picks it up with the error and stack trace intact);
/// 2. optionally a failure-span report via [FailureReporterRegistry] (the
///    `reportAsFailure` flag on [installUncaughtErrorHandlers]).
///
/// Pure Dart only: this is the layer that owns the *contract*; the
/// `zuraffa_flutter` and `zuraffa_observability` companions wire their
/// platform-specific handlers into it.
class UncaughtErrorFunnel {
  UncaughtErrorFunnel._();

  /// Whether the Dart-level handlers were installed by
  /// [installUncaughtErrorHandlers]. The install is idempotent.
  static bool _installed = false;

  /// Whether an uncaught error is also reported as a failure span.
  static bool _reportUncaughtAsFailure = true;

  /// Whether the Dart-level uncaught-error handlers are currently installed.
  static bool get isInstalled => _installed;

  /// Whether uncaught errors are currently reported as failure spans.
  static bool get reportUncaughtAsFailure => _reportUncaughtAsFailure;

  /// Central uncaught-error funnel.
  ///
  /// Logs [error] at `SEVERE` on `Logger.root` with [context] (default
  /// `'Uncaught error'`) and the [stackTrace], then — when [reportAsFailure]
  /// is true and the failure reporter registry has reporters — enqueues a
  /// failure span via [FailureReporterRegistry.reportFailure].
  ///
  /// This is the ONE entry point every family surface (Flutter's
  /// `FlutterError.onError`, `PlatformDispatcher.instance.onError`, isolate
  /// error ports, guarded zones) routes into.
  static void captureUncaught(
    Object error,
    StackTrace stackTrace, {
    String? context,
    bool reportAsFailure = true,
  }) {
    // `Logger.root`, never a named child: a child logger's own level is
    // applied BEFORE the record reaches the root handlers, so
    // `Logger('Zuraffa').level = Level.OFF` would swallow the uncaught-error
    // record even while root logging is fully enabled. An uncaught error is
    // the one record no logger configuration may suppress.
    Logger.root.severe(context ?? 'Uncaught error', error, stackTrace);

    if (reportAsFailure && _reportUncaughtAsFailure) {
      FailureReporterRegistry.instance.reportFailure(
        appFailureFrom(error, stackTrace),
        stackTrace: stackTrace,
      );
    }
  }

  /// The isolate error port, opened on first use.
  ///
  /// `Isolate.spawn(..., onError: port)` requires the *spawning* isolate to
  /// listen on this port; a spawned isolate's uncaught errors arrive here.
  /// It is nullable rather than `final` because [closeUncaughtErrorHandlers]
  /// closes it — an open [ReceivePort] keeps its isolate alive — and the next
  /// install opens a fresh one.
  static ReceivePort? _isolateErrorPort;

  static StreamSubscription<dynamic>? _isolateErrorSubscription;

  static ReceivePort get _isolateErrorPortOrOpen =>
      _isolateErrorPort ??= ReceivePort();

  /// Install the Dart-level uncaught-error handlers. Idempotent: a second
  /// call updates the failure-reporting preference and returns without
  /// reinstalling.
  ///
  /// Installs a listener on the isolate error port so uncaught errors from
  /// any isolate spawned with `onError: UncaughtErrorFunnel.isolateErrorPort`
  /// (the port this class owns) reach [captureUncaught]. The guarded-zone
  /// side is [runGuarded], the boot every app should use.
  ///
  /// When [reportAsFailure] is `true` (the default) an uncaught error also
  /// produces a failure-span report via the [FailureReporterRegistry].
  static void installUncaughtErrorHandlers({bool reportAsFailure = true}) {
    _reportUncaughtAsFailure = reportAsFailure;

    if (_installed) return;
    _installed = true;

    _isolateErrorSubscription ??= _isolateErrorPortOrOpen.listen((
      Object? message,
    ) {
      // An isolate `onError` port delivers a two-element list
      // `[error, stackTrace]`. A value that cannot cross an isolate boundary
      // (any non-sendable object, e.g. a StateError) arrives as its
      // `toString()`, so the error is taken as an Object and the stack trace
      // is decoded from whatever crossed the boundary.
      if (message is List && message.length == 2) {
        captureUncaught(
          message[0],
          _decodeIsolateStackTrace(message[1]),
          context: 'Uncaught error in isolate',
        );
      }
    });
  }

  /// Removes the Dart-level uncaught-error handlers installed by
  /// [installUncaughtErrorHandlers].
  ///
  /// Closes the isolate error port and cancels its listener, then clears
  /// [isInstalled] so a later [installUncaughtErrorHandlers] opens a fresh
  /// port. This is the shutdown a short-lived program needs: an open
  /// [ReceivePort] counts as live work, so without it a program that installs
  /// the handlers never exits once its own work is done.
  ///
  /// Closing the port is final for any isolate that already holds
  /// [isolateErrorPort] — its errors no longer reach the funnel, so this is a
  /// shutdown, not a pause.
  static void closeUncaughtErrorHandlers() {
    _isolateErrorSubscription?.cancel();
    _isolateErrorSubscription = null;
    _isolateErrorPort?.close();
    _isolateErrorPort = null;
    _installed = false;
  }

  /// The error port a spawned isolate should use as its `onError`.
  ///
  /// Pass it to `Isolate.spawn(..., onError: UncaughtErrorFunnel.isolateErrorPort)`
  /// so the spawned isolate's uncaught errors reach [captureUncaught].
  static SendPort get isolateErrorPort => _isolateErrorPortOrOpen.sendPort;

  /// Restores the funnel's process-global state for a test.
  ///
  /// The funnel is a process-wide singleton by design, which is exactly what
  /// makes it order-dependent in a suite: without this seam the test that
  /// installs the handlers decides what every later test sees, and the suite
  /// only passes in declaration order. Tests call it from `setUp` and
  /// `tearDown`; production code has no reason to.
  @visibleForTesting
  static void resetForTest() {
    closeUncaughtErrorHandlers();
    _reportUncaughtAsFailure = true;
  }

  /// Decodes the stack trace an isolate `onError` port delivered.
  ///
  /// Every current SDK sends it as a [String] (Dart 3.11 delivers
  /// `[error, stack]` with *both* elements strings), so a plain
  /// `rawStackTrace is StackTrace` test silently throws the isolate's real
  /// throw site away and logs this listener's own stack instead. A value that
  /// is already a [StackTrace] passes through, and an absent one falls back
  /// to [StackTrace.current].
  static StackTrace _decodeIsolateStackTrace(Object? rawStackTrace) =>
      switch (rawStackTrace) {
        final StackTrace stackTrace => stackTrace,
        final String text => StackTrace.fromString(text),
        _ => StackTrace.current,
      };

  /// The guarded boot every Zuraffa-family app should use.
  ///
  /// Runs [body] inside a `runZonedGuarded` zone whose `onError` defaults to
  /// [captureUncaught] — so any error the body lets escape is logged at
  /// `SEVERE` on `Logger.root` and optionally reported as a failure span.
  ///
  /// Pass [onError] to override the funnel (e.g. to add context-specific
  /// handling); the override still fires INSTEAD of the funnel, so a custom
  /// handler that also wants the funnel must call [captureUncaught] itself.
  ///
  /// [zoneSpecification], when given, is passed through to `runZonedGuarded`
  /// alongside the funnel's own `handleUncaughtError` spec, so the funnel can
  /// never be dropped from a guarded boot.
  ///
  /// Returns `void` on purpose: the guarded zone tracks [body]'s future and
  /// routes its errors to the handler, while the caller's own `main` (or boot
  /// function) stays free to await its own work. Returning the body's future
  /// would re-throw a handled error into the caller, which is the opposite of
  /// what a boot funnel is for.
  static void runGuarded(
    FutureOr<void> Function() body, {
    void Function(Object error, StackTrace stackTrace)? onError,
    ZoneSpecification? zoneSpecification,
  }) {
    final handler = onError ?? captureUncaught;
    runZonedGuarded<void>(body, handler, zoneSpecification: zoneSpecification);
  }
}
