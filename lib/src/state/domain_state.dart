import 'package:meta/meta.dart';
import 'package:zuraffa/zuraffa.dart';

/// Base class for auto-generated **DomainState**.
///
/// [DomainState] is a read-only container of [SignalSlice]s that is
/// **regenerated on every `zfa build`**. Never edit this file manually.
///
/// For transient UI state (dropdowns, tabs, scroll position), use
/// [ViewState] instead.
///
/// ```dart
/// // GENERATED — do not edit
/// class ProductDetailDomainState extends DomainState {
///   ProductDetailDomainState({required super.presenter});
///
///   late final product = bind<Product>('product', getProductUseCase, params);
///   late final reviews = bind<List<Review>>('reviews', getReviewsUseCase, params);
/// }
/// ```
@immutable
abstract class DomainState {
  DomainState({required SlicePresenter presenter}) : _presenter = presenter;

  final SlicePresenter _presenter;

  /// Bind a UseCase to a named slice in the underlying presenter.
  ///
  /// This is called by generated code only.
  SignalSlice<T> bind<T>(
    String sliceKey,
    ZuraffaUseCase<dynamic, T> useCase,
    dynamic params,
  ) => _presenter.bind(sliceKey, useCase, params);

  /// All slice keys managed by this domain state.
  Set<String> get sliceKeys => _presenter.sliceKeys;

  /// Access a slice by key. Returns `null` if not bound.
  SignalSlice<T>? slice<T>(String key) => _presenter.slice<T>(key);

  @override
  String toString() => 'DomainState(keys=${_presenter.sliceKeys.toList()})';
}
