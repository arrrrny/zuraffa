import 'package:zuraffa/zuraffa.dart';

/// The resolved presentation state of a [FragmentBuilder] for a single
/// rebuild cycle.
///
/// The mapping from slice result to state is:
///
/// - `error`   — the slice's [SignalSlice.error] is set (failure result), or
///   the emitted data failed the runtime type guard (see [FragmentBuilder]).
/// - `loading` — the slice is actively loading and has no data.
/// - `empty`   — the slice succeeded but the value represents "no data"
///   (`null`, or an empty `Iterable`/`Map`/`String`).
/// - `data`    — the slice succeeded with a non-empty value.
enum FragmentState {
  /// The fragment has not processed any emission yet.
  initial,

  /// The bound slice is actively loading with no data.
  loading,

  /// The bound slice failed.
  error,

  /// The bound slice succeeded but holds "no data".
  empty,

  /// The bound slice succeeded with data.
  data,
}

/// A reactive fragment that rebuilds only when its bound [SignalSlice]
/// changes (spec 038 FR-002, FR-003).
///
/// `FragmentBuilder` is the v6 domain-state builder: it subscribes to exactly
/// one signal slice (one use-case result) and re-invokes exactly one builder
/// per slice emission — never for sibling slices, never for the enclosing
/// view. Optional [onLoading], [onError], and [onEmpty] builders cover the
/// three universal presentation states; omitting any of them renders `null`
/// output for that state (the framework never forces a default UI).
///
/// ```dart
/// context.attach(FragmentBuilder<Product>(
///   slice: presenter.domain.slice<Product>('product')!,
///   onLoading: (context) => const ProductSkeleton(),
///   onError: (context, error) => ErrorCard(error: error.message),
///   onEmpty: (context) => const EmptyProductsView(),
///   builder: (context, product) => ProductCard(product: product),
/// ));
/// ```
///
/// ## Deterministic rebuild semantics
///
/// Every emission processed while attached is exactly one rebuild cycle,
/// including the eager initial delivery on attach. Rapid successive emissions
/// (e.g. a user typing) therefore rebuild once per value — deterministic and
/// uncoalesced; there is no built-in debounce. After [ViewFragment.detach]
/// (or host unmount) emissions are ignored entirely: no rebuild, no output
/// change, no errors (FR-008 "in-flight async" edge case).
class FragmentBuilder<S> extends ViewFragment {
  /// Creates a fragment bound to [slice].
  ///
  /// [builder] renders the data state; [onLoading]/[onError]/[onEmpty] are
  /// optional state builders.
  FragmentBuilder({
    required this.slice,
    required this.builder,
    this.onLoading,
    this.onError,
    this.onEmpty,
    super.debugLabel,
  });

  /// The single signal slice this fragment subscribes to.
  final SignalSlice<S> slice;

  /// Builder for the data state — receives the current slice value.
  final Object? Function(ViewContext context, S data) builder;

  /// Optional builder for the loading state (active load, no data yet).
  final Object? Function(ViewContext context)? onLoading;

  /// Optional builder for the error state — receives the [AppFailure].
  final Object? Function(ViewContext context, AppFailure error)? onError;

  /// Optional builder for the empty/no-data state.
  final Object? Function(ViewContext context)? onEmpty;

  SignalSubscription? _subscription;
  FragmentState _state = FragmentState.initial;

  /// The presentation state resolved by the most recent rebuild cycle.
  FragmentState get state => _state;

  @override
  void onAttach() {
    if (slice.isDisposed) {
      // A disposed slice never emits; stay inert rather than throwing from
      // deep inside the render path (FR-008).
      return;
    }
    // Signal.listen delivers the current result eagerly, so the initial
    // render happens synchronously on attach.
    _subscription = slice.listen(_onSliceChange);
  }

  @override
  void onDetach() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onSliceChange(S? data, AppFailure? error) {
    if (!isAttached) return;

    Object? result;
    if (error != null) {
      // 1. Failure result — error state.
      _state = FragmentState.error;
      result = onError?.call(context!, error);
    } else if (data == null) {
      if (slice.isLoading) {
        // 2. Active load with no data — loading state.
        _state = FragmentState.loading;
        result = onLoading?.call(context!);
      } else {
        // 3. Success (or idle) with no data — empty state. A null value is
        // "no data" per the FR-008 edge case.
        _state = FragmentState.empty;
        result = onEmpty?.call(context!);
      }
    } else {
      // 4. Type guard: a dynamic slice emitting a value whose runtime type
      // is not S must surface clearly instead of crashing the builder
      // (FR-008 "type changes" edge case). For S == dynamic this never
      // triggers.
      final dynamic probe = data;
      if (probe is! S) {
        _state = FragmentState.error;
        final repr = probe.toString();
        final clipped = repr.length > 40 ? repr.substring(0, 40) : repr;
        result = onError?.call(
          context!,
          AppFailure.validation(
            'FragmentBuilder<$S> received ${probe.runtimeType} '
            '($clipped) which is not assignable to $S. '
            'Check the slice type or the use-case return type.',
          ),
        );
      } else if (_isEmptyValue(data)) {
        // 5. Empty collection/string is "no data" (FR-008 null/default edge).
        _state = FragmentState.empty;
        result = onEmpty?.call(context!);
      } else {
        // 6. Data state.
        _state = FragmentState.data;
        result = builder(context!, data);
      }
    }
    recordRebuild(result);
  }

  /// Whether a non-null [data] value represents "no data": an empty
  /// `Iterable`, `Map`, or `String`.
  static bool _isEmptyValue(Object data) =>
      (data is Iterable && data.isEmpty) ||
      (data is Map && data.isEmpty) ||
      (data is String && data.isEmpty);
}
