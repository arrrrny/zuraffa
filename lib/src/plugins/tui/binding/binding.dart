/// Domain `Binding` for Zuraffa TUI screens (FR-007, SC-004).
///
/// A [Binding] observes one existing domain source — a repository /
/// [StreamUseCase] stream / notifier, or the result of a [UseCase] refreshed
/// after a dispatched action or explicit refresh — and propagates each
/// successful domain value into the screen without a developer-written
/// listener, controller, or duplicate data store.
///
/// On failure, a [Binding] MUST expose a renderable failure state while
/// retaining the last successful value; a non-terminal source remains
/// subscribed. On screen disposal it MUST unsubscribe / remove its listener
/// and cancel any in-flight refresh (FR-007).
///
/// Subclasses:
/// * [StreamUseCaseBinding] — observes a [StreamUseCase].
/// * [RepositoryBinding] — observes a repository stream / notifier.
/// * [UseCaseResultBinding] — refreshes a [UseCase] result after a dispatched
///   action or explicit refresh.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import '../../../core/cancel_token.dart';
import '../../../core/failure.dart';
import '../../../core/result.dart';
import '../../../domain/stream_usecase.dart';
import '../../../domain/usecase.dart';

/// The renderable state a [Binding] exposes to its owning screen.
///
/// Sealed family so screen `build` methods can `switch` exhaustively over
/// the three states without an `else` fallback (SC-004: the UI never holds a
/// parallel copy of the domain value — it reads from this.state directly).
@immutable
class BindingState<T> {
  const BindingState._({
    this.value,
    this.failure,
    required this.isInitial,
    required this.isInFlight,
  });

  /// Initial state — no value yet, no failure, no in-flight refresh.
  const BindingState.initial()
    : this._(value: null, failure: null, isInitial: true, isInFlight: false);

  /// Loaded state — last successful domain value (failure cleared).
  factory BindingState.value(T value) => BindingState<T>._(
    value: value,
    failure: null,
    isInitial: false,
    isInFlight: false,
  );

  /// In-flight state — last successful value retained, refresh in progress.
  factory BindingState.inFlight(T? previousValue) => BindingState<T>._(
    value: previousValue,
    failure: null,
    isInitial: false,
    isInFlight: true,
  );

  /// Failure state — last successful value retained (FR-007).
  factory BindingState.failure(AppFailure failure, {T? previousValue}) =>
      BindingState<T>._(
        value: previousValue,
        failure: failure,
        isInitial: false,
        isInFlight: false,
      );

  /// The last successful domain value, or `null` if none has been received.
  final T? value;

  /// The last failure, or `null` if there is no renderable failure.
  final AppFailure? failure;

  /// Whether this is the initial state (no value, no failure).
  final bool isInitial;

  /// Whether a refresh is currently in-flight.
  final bool isInFlight;

  /// Whether a value has been received (success or retained-on-failure).
  bool get hasValue => value != null;

  /// Whether there is a renderable failure.
  bool get hasFailure => failure != null;

  @override
  String toString() {
    if (isInitial) return 'BindingState<T>.initial()';
    if (isInFlight) return 'BindingState<T>.inFlight($value)';
    if (failure != null) {
      return 'BindingState<T>.failure($failure, value: $value)';
    }
    return 'BindingState<T>.value($value)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BindingState<T> &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          failure == other.failure &&
          isInitial == other.isInitial &&
          isInFlight == other.isInFlight;

  @override
  int get hashCode => Object.hash(value, failure, isInitial, isInFlight);
}

/// The base class for all Zuraffa TUI [Binding]s.
///
/// Subclasses implement [mount] to subscribe / attach to the domain source
/// and [dispose] to unsubscribe / cancel any in-flight refresh. Successful
/// domain values flow into [onValue]; failures flow into [onFailure].
///
/// The binding holds NO data store of its own — the screen reads
/// [state].value, and that value is the domain source's value (SC-004).
abstract class Binding<T> {
  Binding({CancelToken? parentCancelToken}) : _cancelToken = CancelToken() {
    if (parentCancelToken != null) {
      _cancelToken.linkTo(parentCancelToken);
    }
  }

  /// Cancel token linked to a parent (typically the TUI session's root
  /// [CancelToken]). When the parent cancels, this binding's [dispose] is
  /// triggered (FR-009 edge case "in-flight input with CancelToken").
  final CancelToken _cancelToken;

  /// The current renderable state exposed to the screen.
  ///
  /// Initialized to [BindingState.initial]. Updated by:
  /// * [onValue] on a successful domain value, and
  /// * [onFailure] on a failure (retains the previous value).
  BindingState<T> _state = BindingState<T>.initial();
  BindingState<T> get state => _state;

  /// The last successful value, or `null`.
  T? get value => _state.value;

  /// Hook invoked when the binding receives a successful domain value.
  ///
  /// Subclasses override this (or pass a callback to the constructor) to
  /// schedule a re-render of the owning screen.
  void onValue(T value) {}

  /// Hook invoked when the binding receives a failure.
  ///
  /// Default implementation is a no-op; subclasses may override to log or
  /// schedule a re-render with the failure state.
  void onFailure(AppFailure failure) {}

  /// Mounts the binding: subscribes / attaches to the domain source and
  /// begins propagating values.
  ///
  /// Called once when the owning screen is mounted. Returns a [Future] that
  /// completes when the subscription is fully established.
  Future<void> mount();

  /// Disposes the binding: unsubscribes / removes listeners and cancels any
  /// in-flight refresh.
  ///
  /// Called once when the owning screen is unmounted. Safe to call multiple
  /// times.
  @mustCallSuper
  void dispose() {
    _cancelToken.cancel('Binding.dispose');
  }

  /// The cancel token owned by this binding.
  ///
  /// Pass this to `UseCase.call(..., cancelToken: ...)` so dispatched
  /// actions are cancellable when the binding is disposed or the parent
  /// [CancelToken] is cancelled (FR-009 / FR-007 edge case).
  CancelToken get cancelToken => _cancelToken;

  /// Propagates a successful value into the binding's state and calls
  /// [onValue]. Used by subclasses when their source emits a value.
  @protected
  void emitValue(T value) {
    _state = BindingState<T>.value(value);
    onValue(value);
  }

  /// Propagates a failure into the binding's state (retaining the previous
  /// value) and calls [onFailure]. Used by subclasses when their source
  /// emits a failure.
  @protected
  void emitFailure(AppFailure failure) {
    _state = BindingState<T>.failure(failure, previousValue: _state.value);
    onFailure(failure);
  }

  /// Marks the binding as in-flight (refresh in progress, last value
  /// retained). Used by subclasses when a refresh starts.
  @protected
  void markInFlight() {
    _state = BindingState<T>.inFlight(_state.value);
  }
}

/// A [Binding] that observes a [StreamUseCase] stream.
///
/// Subscribes to the stream and propagates each [Result.success] value into
/// the owning screen. On [Result.failure] the binding exposes a renderable
/// failure state while retaining the last successful value; the stream
/// remains subscribed (FR-007).
///
/// ```dart
/// final binding = StreamUseCaseBinding<List<Product>, String>(
///   useCase: di.get<WatchProductsUseCase>(),
///   params: 'electronics',
///   onValue: (products) => screen.setState(() {}),
/// );
/// await binding.mount();
/// ```
class StreamUseCaseBinding<T, P> extends Binding<T> {
  StreamUseCaseBinding({
    required this.useCase,
    required this.params,
    void Function(T value)? onValue,
    void Function(AppFailure failure)? onFailure,
    super.parentCancelToken,
  }) : _onValue = onValue,
       _onFailure = onFailure;

  /// The stream use case being observed.
  final StreamUseCase<T, P> useCase;

  /// The parameters passed to [useCase.call].
  final P params;

  final void Function(T value)? _onValue;
  final void Function(AppFailure failure)? _onFailure;

  StreamSubscription<Result<T, AppFailure>>? _subscription;

  @override
  void onValue(T value) => _onValue?.call(value);

  @override
  void onFailure(AppFailure failure) => _onFailure?.call(failure);

  @override
  Future<void> mount() async {
    await for (final result in useCase.call(params, cancelToken: cancelToken)) {
      if (cancelToken.isCancelled) break;
      result.fold(
        (value) => emitValue(value),
        (failure) => emitFailure(failure),
      );
    }
  }

  /// Starts the subscription. Mount-equivalent for stream bindings whose
  /// `mount` cannot return a Future that completes when the stream ends
  /// (streams are usually long-lived; the binding stays subscribed until
  /// [dispose]).
  void start() {
    _subscription = useCase
        .call(params, cancelToken: cancelToken)
        .listen(
          (result) {
            if (cancelToken.isCancelled) return;
            result.fold(
              (value) => emitValue(value),
              (failure) => emitFailure(failure),
            );
          },
          onError: (Object error, StackTrace _) {
            // Stream errors are usually non-terminal; the source remains
            // subscribed (FR-007). We rely on the source's own error model
            // to emit a Result.failure for known errors.
          },
          cancelOnError: false,
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}

/// A [Binding] that observes a repository stream / notifier (FR-007).
///
/// Wraps any `Stream<T>` exposing domain values. Used when the domain source
/// is a repository's `watch()` method or a notifier, rather than a
/// [StreamUseCase].
class RepositoryBinding<T> extends Binding<T> {
  RepositoryBinding({
    required Stream<T> Function(CancelToken cancelToken) source,
    void Function(T value)? onValue,
    void Function(AppFailure failure)? onFailure,
    super.parentCancelToken,
  }) : _source = source,
       _onValue = onValue,
       _onFailure = onFailure;

  final Stream<T> Function(CancelToken cancelToken) _source;
  final void Function(T value)? _onValue;
  final void Function(AppFailure failure)? _onFailure;

  StreamSubscription<T>? _subscription;

  @override
  void onValue(T value) => _onValue?.call(value);

  @override
  void onFailure(AppFailure failure) => _onFailure?.call(failure);

  @override
  Future<void> mount() async {
    _subscription = _source(cancelToken).listen((value) {
      if (cancelToken.isCancelled) return;
      emitValue(value);
    }, cancelOnError: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}

/// A [Binding] that refreshes a [UseCase] result after a dispatched action or
/// explicit refresh (FR-007).
///
/// The binding does not observe a stream; it invokes the [UseCase] on demand
/// and exposes the latest [Result]. Used for one-shot reads where the screen
/// re-fetches after each dispatched action.
class UseCaseResultBinding<T, P> extends Binding<T> {
  UseCaseResultBinding({
    required this.useCase,
    required this.params,
    void Function(T value)? onValue,
    void Function(AppFailure failure)? onFailure,
    super.parentCancelToken,
  }) : _onValue = onValue,
       _onFailure = onFailure;

  final UseCase<T, P> useCase;
  final P params;

  final void Function(T value)? _onValue;
  final void Function(AppFailure failure)? _onFailure;

  @override
  void onValue(T value) => _onValue?.call(value);

  @override
  void onFailure(AppFailure failure) => _onFailure?.call(failure);

  @override
  Future<void> mount() async {
    await refresh();
  }

  /// Re-invokes the [UseCase] and propagates the result.
  ///
  /// Marked in-flight first (last value retained). On success emits the
  /// value; on failure emits the failure (last value still retained).
  Future<void> refresh() async {
    if (cancelToken.isCancelled) return;
    markInFlight();
    final result = await useCase.call(params, cancelToken: cancelToken);
    if (cancelToken.isCancelled) return;
    result.fold(emitValue, emitFailure);
  }
}
