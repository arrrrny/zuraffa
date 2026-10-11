/// The light trace seam (spec 1653-trim-heavy-deps, issue #1661).
///
/// Core's hook-context assembly reads `traceId`/`spanId` through THIS
/// interface — never through an observability-vendor type. The default
/// instance yields nulls (the same values core produces today when no
/// span is active); the observability companion
/// (`package:zuraffa_observability`) replaces [instance] with its
/// vendor-backed observer at app startup. Seams are contracts; the heavy
/// implementations are plugins.
library;

abstract class TraceObserver {
  /// The process-wide observer. Defaults to the no-op observer; the
  /// observability companion assigns a vendor-backed one during init.
  static TraceObserver instance = const _NoOpTraceObserver();

  /// Restores the no-op observer (test seam and teardown safety).
  static void resetToDefault() {
    instance = const _NoOpTraceObserver();
  }

  String? get currentTraceId;

  String? get currentSpanId;
}

class _NoOpTraceObserver implements TraceObserver {
  const _NoOpTraceObserver();

  @override
  String? get currentTraceId => null;

  @override
  String? get currentSpanId => null;
}
