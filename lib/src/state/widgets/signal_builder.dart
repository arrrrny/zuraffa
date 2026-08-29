import 'package:zuraffa/zuraffa.dart';

/// A lightweight reactive fragment that rebuilds only when its bound UI
/// [Signal] changes (spec 038 FR-004, US4).
///
/// `SignalBuilder` is the v6 UI-state builder: it subscribes to exactly one
/// pure UI signal (edit mode, search text, selected tab — anything that is
/// NOT domain data) and re-invokes [builder] per value change. It is the
/// counterpart of [FragmentBuilder], which binds domain [SignalSlice]s; the
/// two never trigger each other.
///
/// ```dart
/// context.attach(SignalBuilder<bool>(
///   signal: viewState.isEditMode,
///   builder: (context, isEditMode) =>
///       isEditMode ? const EditToolbar() : const ReadOnlyView(),
/// ));
/// ```
///
/// ## Disposal and missing values
///
/// A [Signal] must be constructed with an initial value; when that value is
/// `null` (a nullable signal), the builder simply receives `null` on the
/// eager initial delivery — a defined default, never a crash (FR-008
/// "missing initial values" edge case). When the signal is disposed, the
/// fragment renders [fallback] (or nothing when omitted) on every subsequent
/// read of [output], without throwing (FR-008 "disposed signal" edge case).
class SignalBuilder<T> extends ViewFragment {
  /// Creates a fragment bound to [signal].
  SignalBuilder({
    required this.signal,
    required this.builder,
    this.fallback,
    super.debugLabel,
  });

  /// The single UI signal this fragment subscribes to.
  final Signal<T> signal;

  /// Builder invoked with each signal value, including the eager initial
  /// delivery on attach.
  final Object? Function(ViewContext context, T value) builder;

  /// Optional output rendered while (or after) the signal is disposed.
  ///
  /// The context is `null` when the fragment itself is detached; otherwise it
  /// is the fragment's live view context. When omitted, a disposed signal
  /// renders `null` ("nothing").
  final Object? Function(ViewContext? context)? fallback;

  SignalSubscription? _subscription;

  @override
  void onAttach() {
    if (signal.isDisposed) {
      // A disposed signal never emits; stay inert rather than throwing from
      // inside the render path (FR-008).
      return;
    }
    // Signal.listen delivers the current value eagerly, so the initial
    // render happens synchronously on attach — including `null` for a
    // nullable signal with no meaningful initial value.
    _subscription = signal.listen(_onSignalChange);
  }

  @override
  void onDetach() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// The fragment output: the last [builder] result, or the [fallback]
  /// result when the source signal has been disposed.
  ///
  /// Reading this after disposal never throws (US4-S3): a disposed signal
  /// renders the fallback — or `null` when none was provided.
  @override
  Object? get output => signal.isDisposed
      ? fallback?.call(isAttached ? context : null)
      : super.output;

  void _onSignalChange(T value) {
    if (!isAttached) return;
    recordRebuild(builder(context!, value));
  }
}
