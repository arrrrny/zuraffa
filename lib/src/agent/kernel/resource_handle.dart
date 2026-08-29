import 'dart:async';

/// A disposable resource handle that participates in cancellation
/// (FR-004, FR-006). Examples: webview pool entry, network request,
/// open stream.
///
/// On cancellation, the kernel calls [dispose] inside the grace-period
/// race. Resources that fail to dispose within the grace window are
/// reported by the post-cancellation leak assertion (FR-006).
abstract class ResourceHandle {
  /// Human-readable identifier for diagnostics.
  String get handleId;

  /// Disposes the resource. MUST be safe to call multiple times (idempotent).
  /// Returns a [Future] that completes once the resource is released.
  Future<void> dispose();

  /// Whether the resource has been disposed. Read by the post-cancellation
  /// leak assertion ([CancelToken.leaked], FR-006) to detect handles that
  /// failed to release within the grace period. Real implementations MUST
  /// override this to reflect their actual disposal state; the default
  /// (`false`) assumes not disposed so a non-overriding implementation is
  /// reported as leaked rather than silently passed as cleanly released.
  bool get isDisposed => false;
}

/// A test-friendly [ResourceHandle] that records dispose calls.
class FakeResourceHandle implements ResourceHandle {
  FakeResourceHandle(this.handleId, {this.disposeDelay = Duration.zero});

  @override
  final String handleId;

  final Duration disposeDelay;

  int disposeCallCount = 0;
  bool get wasDisposed => disposeCallCount > 0;

  @override
  bool get isDisposed => wasDisposed;

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    if (disposeDelay > Duration.zero) {
      await Future<void>.delayed(disposeDelay);
    }
  }
}

/// A resource that simulates a leak (never reports disposed within the
/// grace window). Used to verify the post-cancellation leak assertion.
class LeakingResourceHandle implements ResourceHandle {
  LeakingResourceHandle(this.handleId);

  @override
  final String handleId;

  bool disposed = false;
  Completer<void>? _stall;

  @override
  bool get isDisposed => disposed;

  void completeDispose() {
    disposed = true;
    _stall?.complete();
  }

  @override
  Future<void> dispose() {
    if (disposed) return Future<void>.value();
    // Never resolves until completeDispose() is called externally.
    _stall = Completer<void>();
    return _stall!.future;
  }
}
