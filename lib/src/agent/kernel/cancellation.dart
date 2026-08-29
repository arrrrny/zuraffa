import 'dart:async';

import 'resource_handle.dart';

/// A cancellation token that triggers the grace-period disposal
/// protocol (FR-004, FR-006).
class CancelToken {
  CancelToken({this.gracePeriod = const Duration(milliseconds: 250)});

  final Duration gracePeriod;

  final Completer<void> _triggered = Completer<void>();
  final Completer<void> _settled = Completer<void>();

  /// Whether cancellation has been triggered.
  bool get isTriggered => _triggered.isCompleted;

  /// Whether the disposal race has fully settled (resources disposed).
  bool get isSettled => _settled.isCompleted;

  /// Future that completes when cancellation has fully settled.
  Future<void> get onSettled => _settled.future;

  /// Triggers cancellation. Returns a future that completes once the
  /// grace-period disposal race settles (resources disposed or timed out).
  Future<void> trigger(List<ResourceHandle> handles) {
    if (_triggered.isCompleted) return _settled.future;
    _triggered.complete();

    final disposals = handles.map((h) => h.dispose()).toList();
    final disposeAll = Future.wait(disposals, eagerError: false);

    Future.any<void>([
      disposeAll,
      Future<void>.delayed(gracePeriod),
    ]).whenComplete(() {
      if (!_settled.isCompleted) _settled.complete();
    });

    return _settled.future;
  }

  /// Returns true if [handle] failed to dispose within the grace period
  /// (FR-006 post-cancellation leak assertion).
  ///
  /// Disposal state is read polymorphically from [ResourceHandle.isDisposed],
  /// so the assertion applies to any implementation rather than only the test
  /// fakes ([FakeResourceHandle]/[LeakingResourceHandle]).
  bool leaked(ResourceHandle handle) => !handle.isDisposed;
}

/// Result of a cancellation sweep.
class CancellationResult {
  CancellationResult({
    required this.disposedHandles,
    required this.leakedHandles,
    required this.timedOut,
  });

  final List<String> disposedHandles;
  final List<String> leakedHandles;
  final bool timedOut;

  /// True iff zero leaked handles (FR-006).
  bool get zeroLeak => leakedHandles.isEmpty;
}

/// Runs the cancellation protocol against [handles] using [token].
/// Returns a [CancellationResult] once the grace period completes.
Future<CancellationResult> runCancellation(
  CancelToken token,
  List<ResourceHandle> handles,
) async {
  await token.trigger(handles);

  final disposed = <String>[];
  final leaked = <String>[];
  for (final h in handles) {
    if (token.leaked(h)) {
      leaked.add(h.handleId);
    } else {
      disposed.add(h.handleId);
    }
  }

  return CancellationResult(
    disposedHandles: disposed,
    leakedHandles: leaked,
    timedOut: leaked.isNotEmpty,
  );
}
