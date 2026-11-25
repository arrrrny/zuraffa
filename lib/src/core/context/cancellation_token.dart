/// Cooperative cancellation for the v8 chord runtime.
///
/// [CancellationToken] is a pure-Dart, allocation-light primitive that flows
/// through [ZfaContext] so long-running work can observe cancellation without
/// every method signature carrying a flag. Cancellation is **cooperative**: a
/// token never interrupts anything by itself — the operation polls
/// [isCancelled] / [throwIfCancelled] at its own cancellation points.
///
/// ## Cascading cancellation
///
/// A token created with [child] is linked to its parent: cancelling the parent
/// cancels every descendant, carrying the parent's [reason] down the tree. A
/// child created *after* its parent was cancelled is born already cancelled.
///
/// ## The system token
///
/// [CancellationToken.system] never cancels. It backs
/// [ZfaContext.background], the non-cancelling system context whose work must
/// outlive any single request scope.
///
/// ## Chord invariant
///
/// A token carries cancellation signal only. Repositories, database handles and
/// HTTP clients never live here or in [ZfaContext] — that is the strict Chord
/// rule the v8 runtime enforces.
class CancellationToken {
  CancellationToken._() : _cancelled = false, _reason = null, _parent = null;

  /// A fresh, uncancelled root token.
  factory CancellationToken() => CancellationToken._();

  /// A token that is permanently uncancellable.
  ///
  /// [cancel] is a no-op and [isCancelled] is always `false`. Used for the
  /// background system context, whose lifetime is not bounded by any request.
  factory CancellationToken.system() {
    final token = CancellationToken._();
    token._system = true;
    return token;
  }

  bool _cancelled;
  String? _reason;
  CancellationToken? _parent;
  bool _system = false;
  final List<CancellationToken> _children = [];

  /// Whether this token — or any ancestor — has been cancelled.
  bool get isCancelled =>
      _system ? false : (_cancelled || (_parent?.isCancelled ?? false));

  /// Alias for [isCancelled], matching the `CancellationToken` naming used
  /// across the chord runtime.
  bool get isCancellationRequested => isCancelled;

  /// The cancellation reason, inherited from the cancelling ancestor.
  String? get reason => _system ? null : (_reason ?? _parent?.reason);

  /// Cancel this token and cascade the cancellation to every child.
  ///
  /// Idempotent: the first [reason] wins and later calls are ignored. A
  /// [CancellationToken.system] token ignores this call entirely.
  void cancel([String? reason]) {
    if (_system || _cancelled) return;
    _cancelled = true;
    _reason = reason;
    final children = List<CancellationToken>.of(_children);
    _children.clear();
    for (final child in children) {
      child.cancel(reason);
    }
  }

  /// Throw a [CancellationTokenException] when cancellation has been
  /// requested. Call this at a cancellation point in cooperative work.
  void throwIfCancelled() {
    if (isCancelled) {
      throw CancellationTokenException(reason);
    }
  }

  /// Create a child token linked to this one.
  ///
  /// The child is cancelled when this token is cancelled. If this token is
  /// already cancelled, the child is born cancelled with the same reason.
  CancellationToken child() {
    final token = CancellationToken._();
    token._parent = this;
    _children.add(token);
    // Born cancelled if the parent already is.
    if (isCancelled) {
      token.cancel(reason);
    }
    return token;
  }
}

/// Thrown by [CancellationToken.throwIfCancelled] at a cancellation point.
class CancellationTokenException implements Exception {
  /// The reason the operation was cancelled, if one was provided.
  final String? reason;

  const CancellationTokenException([this.reason]);

  @override
  String toString() =>
      'CancellationTokenException: ${reason ?? 'operation cancelled'}';
}
