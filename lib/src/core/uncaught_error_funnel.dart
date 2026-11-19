import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

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

  static final Logger _logger = Logger('Zuraffa');

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
    _logger.severe(context ?? 'Uncaught error', error, stackTrace);

    if (reportAsFailure && _reportUncaughtAsFailure) {
      FailureReporterRegistry.instance.reportFailure(
        AppFailure.from(error, stackTrace),
        stackTrace: stackTrace,
      );
    }
  }

  /// A [ReceivePort] kept alive for the isolate error port.
  ///
  /// `Isolate.spawn(..., onError: port)` requires the *spawning* isolate to
  /// listen on this port; a spawned isolate's uncaught errors arrive here.
  static final ReceivePort _isolateErrorPort = ReceivePort();

  static StreamSubscription<Object?>? _isolateErrorSubscription;

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

    _isolateErrorSubscription ??= _isolateErrorPort.listen((message) {
      // An isolate `onError` port delivers a two-element list
      // `[error, stackTrace]`. A value that cannot cross an isolate boundary
      // (any non-sendable object, e.g. a StateError) arrives as its
      // `toString()`, so the error is taken as an Object and the stack trace
      // is used only when it is one.
      if (message is List && message.length == 2) {
        final rawStackTrace = message[1];
        captureUncaught(
          message[0],
          rawStackTrace is StackTrace ? rawStackTrace : StackTrace.current,
          context: 'Uncaught error in isolate',
        );
      }
    });
  }

  /// The error port a spawned isolate should use as its `onError`.
  ///
  /// Pass it to `Isolate.spawn(..., onError: UncaughtErrorFunnel.isolateErrorPort)`
  /// so the spawned isolate's uncaught errors reach [captureUncaught].
  static SendPort get isolateErrorPort => _isolateErrorPort.sendPort;

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
