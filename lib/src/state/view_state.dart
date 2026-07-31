import 'package:zuraffa/zuraffa.dart';

/// Base class for developer-extended **ViewState**.
///
/// [ViewState] holds transient UI state — dropdown visibility, active tabs,
/// scroll offsets, form field values — that is **not** tied to domain data.
///
/// This file is **scaffolded once** by `zfa build` and then preserved.
/// The generator will never overwrite an existing ViewState file.
///
/// ```dart
/// // SCAFFOLDED — safe to edit, never regenerated
/// class ProductDetailViewState extends ViewState {
///   ProductDetailViewState() : super();
///
///   final isDescriptionExpanded = Signal<bool>(false);
///   final activeTabIndex = Signal<int>(0);
///   final scrollOffset = Signal<double>(0.0);
/// }
/// ```
abstract class ViewState {
  ViewState();

  /// All [Signal] fields explicitly registered on this ViewState.
  final List<Signal<dynamic>> _signals = [];

  /// Register a signal so it can be disposed with the view state.
  ///
  /// Generated code calls this for every declared Signal field.
  void registerSignal<T>(Signal<T> signal) {
    _signals.add(signal);
  }

  /// Dispose all registered signals.
  void dispose() {
    for (final signal in _signals) {
      signal.dispose();
    }
    _signals.clear();
  }

  /// Whether any signals are still active.
  bool get isActive => _signals.any((s) => !s.isDisposed);

  @override
  String toString() => 'ViewState(signals=${_signals.length})';
}
