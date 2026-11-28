import 'package:zuraffa/zuraffa.dart';

/// Base contract for a feature's normalized **domain state** (v8, ZFA-012).
///
/// A [ZfaFeatureState] holds its entities as **ID slices** — one
/// [AsyncSlice] per principal key — instead of the v6/v7 one-UseCase-per-field
/// [SignalSlice] layout. The normalized shape is what lets a single entity
/// update fan out to every view that keyed on that id, and what the (v8,
/// ZFA-008) `ZfaStore` overlays optimistic `editDraft` previews onto.
///
/// This base is intentionally **store-agnostic**: it owns the ID-slice
/// registry and disposal, while the concrete `<Entity>UiState` that pairs an
/// `activeQuery` with an `editDraft` is generated once the `ZfaQuery<T>` and
/// `ZfaPatch<T>` types land (ZFA-008 / #2156). Keeping the contract here free
/// of those types is what lets the ID-slice half ship before the store does.
///
/// ```dart
/// // GENERATED — do not edit
/// class ProductDomainState extends ZfaFeatureState {
///   ProductDomainState() {
///     bind('sku-1', AsyncSlice<Product>.loading());
///   }
/// }
/// ```
abstract class ZfaFeatureState {
  ZfaFeatureState();

  final Map<String, AsyncSlice<dynamic>> _idSlices =
      <String, AsyncSlice<dynamic>>{};

  /// All principal keys currently held, in insertion order.
  ///
  /// Returns a fresh unmodifiable snapshot on each call, so callers may hold
  /// the result without it tracking later mutations. This is a debug/view
  /// surface, not a hot rebuild path; if it ever lands on one, cache the
  /// snapshot rather than reallocating per access.
  Set<String> get ids => _idSlices.keys.toSet();

  /// The slice bound to [id], or `null` when nothing is bound.
  ///
  /// An id's payload type `T` is **fixed for the lifetime of its binding**:
  /// the first [bind] decides it, and a later [slice]<U> with a different `U`
  /// throws a [StateError] rather than silently mistyping the slice. Re-bind
  /// the id (via [bind]) to change its type.
  AsyncSlice<T>? slice<T>(String id) {
    final slice = _idSlices[id];
    if (slice == null) return null;
    if (slice is! AsyncSlice<T>) {
      throw StateError(
        'Slice for "$id" is ${slice.runtimeType}, not AsyncSlice<T>.',
      );
    }
    return slice;
  }

  /// Replace (or insert) the slice for [id] with an [AsyncSlice<T>].
  ///
  /// Re-binding an id replaces its slice wholesale, so a re-bind with a
  /// different `T` changes the id's payload type. In debug builds an existing
  /// slice of a different `T` trips an assert, catching an accidental type
  /// change that would otherwise only surface later at [slice] read time.
  void bind<T>(String id, AsyncSlice<T> slice) {
    final existing = _idSlices[id];
    assert(
      existing == null || existing is AsyncSlice<T>,
      'Re-binding "$id" changes its payload type from '
      '${existing.runtimeType} to AsyncSlice<$T>. Unbind it first if that is '
      'intended.',
    );
    _idSlices[id] = slice;
  }

  /// Remove the slice for [id], returning it when present.
  AsyncSlice<dynamic>? unbind(String id) => _idSlices.remove(id);

  /// Whether a slice is bound for [id].
  bool contains(String id) => _idSlices.containsKey(id);

  /// Drop every bound slice.
  void dispose() => _idSlices.clear();

  @override
  String toString() =>
      'ZfaFeatureState(ids=${_idSlices.keys.toList(growable: false)})';
}
