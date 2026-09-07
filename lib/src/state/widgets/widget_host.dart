import 'package:meta/meta.dart';

import 'controlled_widget.dart';

/// Error thrown when a reactive fragment is attached outside the context of a
/// mounted [ControlledWidget].
///
/// Spec 038 FR-008 (edge case "FragmentBuilder used outside a
/// ControlledWidget"): misplacement must surface a clear, actionable error —
/// not a silent no-op, and not an unrelated runtime exception from deep inside
/// the render path. This dedicated type is thrown at attach time, the earliest
/// well-defined point, so the mistake is caught during setup.
///
/// ```dart
/// try {
///   detachedContext.attach(FragmentBuilder<int>(...));
/// } on FragmentContextError catch (e) {
///   print(e); // explains exactly how to fix the wiring
/// }
/// ```
class FragmentContextError extends Error {
  /// Creates the error with an actionable [message].
  FragmentContextError(this.message);

  /// Human-readable explanation that names the fix, not just the problem.
  final String message;

  @override
  String toString() =>
      'FragmentContextError: $message\n'
      'Fix: attach fragments inside ControlledWidget.build(context) via '
      'context.attach(fragment) while the host is mounted.';
}

/// A reactive node that can be attached to a [ViewContext].
///
/// [FragmentBuilder] and [SignalBuilder] are the two implementations; the
/// host treats them uniformly for attach/detach bookkeeping. Subclasses
/// subscribe to their reactive source in [onAttach] and cancel the
/// subscription in [onDetach].
///
/// ```dart
/// class MyFragment extends ViewFragment {
///   @override
///   void onAttach() { /* subscribe */ }
///   @override
///   void onDetach() { /* cancel */ }
/// }
/// ```
abstract class ViewFragment {
  /// Creates a fragment with an optional [debugLabel] used in error messages
  /// and debugging output.
  ViewFragment({this.debugLabel});

  /// Optional human-readable label for debugging and error reporting.
  final String? debugLabel;

  ViewContext? _context;
  bool _attached = false;
  int _rebuildCount = 0;
  Object? _output;

  /// Whether this fragment is currently attached to a live view context.
  bool get isAttached => _attached;

  /// The context this fragment is attached to, or `null` when detached.
  ViewContext? get context => _context;

  /// Number of rebuild cycles processed while attached.
  ///
  /// A rebuild cycle is one emission from the fragment's reactive source —
  /// including the eager initial delivery on attach. Changing one slice must
  /// bump only the rebuild count of the fragment bound to it (spec 038
  /// SC-002); sibling fragments and the parent view are unaffected.
  int get rebuildCount => _rebuildCount;

  /// The output of the most recent rebuild cycle.
  ///
  /// The value returned by whichever state builder ran last; `null` when no
  /// builder ran (e.g. a state whose optional builder was omitted).
  Object? get output => _output;

  /// Called by [ViewContext.attach] — subclasses subscribe to their reactive
  /// source here. The base implementation is a no-op.
  @protected
  void onAttach() {}

  /// Called when the fragment detaches — subclasses cancel subscriptions
  /// here. Guaranteed to be called at most once per attach. The base
  /// implementation is a no-op.
  @protected
  void onDetach() {}

  /// Internal: wiring performed by [ViewContext.attach]. Not part of the
  /// public API; attach through `context.attach(fragment)`.
  void attachTo(ViewContext context) {
    if (_attached) return;
    _context = context;
    _attached = true;
    onAttach();
  }

  /// Detach from the host context and stop rebuilding.
  ///
  /// After detach, emissions from the reactive source are ignored (no
  /// rebuild, no output change, no errors) — spec 038 FR-008 "in-flight
  /// async" edge case: a detached or unmounted view never receives state
  /// updates. Detaching an already-detached fragment is a no-op.
  void detach() {
    if (!_attached) return;
    _attached = false;
    onDetach();
  }

  /// Internal: records one rebuild cycle and stores its [result].
  void recordRebuild(Object? result) {
    _rebuildCount++;
    _output = result;
  }
}

/// The mount context handed to [ControlledWidget.build] and to fragment
/// builders.
///
/// A context is live only while its hosting [WidgetHost] is mounted. It is
/// the single attach point for fragments, which is what makes the
/// "outside a ControlledWidget" misuse detectable (see [FragmentContextError]).
///
/// ```dart
/// class ProductView extends ControlledWidget<ProductPresenter> {
///   ProductView({required super.controller});
///
///   @override
///   Object? build(ViewContext context) {
///     context.attach(FragmentBuilder<Product>(
///       slice: controller.domain.slice<Product>('product')!,
///       builder: (context, product) => ProductCard(product),
///     ));
///     return null;
///   }
/// }
/// ```
class ViewContext {
  ViewContext._(this._host);

  final WidgetHost<dynamic> _host;

  /// Whether the hosting [ControlledWidget] is currently mounted.
  bool get isAttached => _host.isMounted;

  /// Attaches [fragment] to this context and returns it.
  ///
  /// Throws [FragmentContextError] when this context is not attached to a
  /// mounted [ControlledWidget] — i.e. when the fragment would live outside a
  /// controlled view's lifecycle (spec 038 FR-008). The rejected fragment is
  /// left detached and unchanged.
  ///
  /// ```dart
  /// final counter = context.attach(
  ///   SignalBuilder<int>(signal: viewState.count, builder: (_, v) => '$v'),
  /// );
  /// ```
  T attach<T extends ViewFragment>(T fragment) {
    if (!isAttached) {
      throw FragmentContextError(
        'Cannot attach ${fragment.runtimeType}'
        '${fragment.debugLabel != null ? " (${fragment.debugLabel})" : ""} '
        'because the hosting ControlledWidget is not mounted. '
        'Fragments must be attached within a mounted ControlledWidget.',
      );
    }
    _host.register(fragment);
    fragment.attachTo(this);
    return fragment;
  }
}

/// Hosts one root [ControlledWidget] and drives its lifecycle.
///
/// The host is the pure-Dart counterpart of a Flutter element: it mounts the
/// view (controller first, then `onInit`, then one initial `build`), tracks
/// the fragments the view attaches, and on unmount tears every fragment down
/// before firing `onDispose` — exactly once each.
///
/// ```dart
/// final host = WidgetHost(ProductDetailView(controller: presenter));
/// host.mount();
/// // ... slices change; only bound fragments rebuild ...
/// host.unmount();
/// ```
class WidgetHost<C> {
  /// Creates a host for [widget].
  WidgetHost(this.widget);

  /// The root controlled view this host mounts.
  final ControlledWidget<C> widget;

  final List<ViewFragment> _fragments = <ViewFragment>[];
  ViewContext? _context;
  bool _mounted = false;
  int _buildCount = 0;

  /// Whether [mount] has been called and [unmount] has not.
  bool get isMounted => _mounted;

  /// How many times the view's `build` has run (once per mount).
  int get buildCount => _buildCount;

  /// The live [ViewContext], or `null` before mount / after unmount.
  ViewContext? get context => _context;

  /// Fragments currently attached to this host's context.
  List<ViewFragment> get fragments => List.unmodifiable(_fragments);

  /// Mounts the view: creates the context, invokes [ControlledWidget.onInit]
  /// exactly once, then runs the view's `build` exactly once for initial
  /// wiring.
  ///
  /// The controller is a final field set at construction, so it is
  /// guaranteed to be available before `onInit` runs (spec 038 FR-007).
  /// Calling [mount] on an already-mounted host is a no-op.
  void mount() {
    if (_mounted) return;
    _mounted = true;
    final context = ViewContext._(this);
    _context = context;
    widget.onInit();
    _buildCount++;
    widget.build(context);
  }

  /// Unmounts the view: detaches every attached fragment (cancelling their
  /// subscriptions), then invokes [ControlledWidget.onDispose] exactly once.
  ///
  /// After unmount, reactive emissions trigger no rebuilds and no state
  /// updates anywhere in this view (spec 038 FR-008 "disposed controller
  /// with in-flight async"). Calling [unmount] on an already-unmounted host
  /// is a no-op.
  void unmount() {
    if (!_mounted) return;
    _mounted = false;
    final detached = List<ViewFragment>.of(_fragments);
    _fragments.clear();
    for (final fragment in detached) {
      fragment.detach();
    }
    widget.onDispose();
    _context = null;
  }

  /// Internal: registration hook used by [ViewContext.attach].
  void register(ViewFragment fragment) => _fragments.add(fragment);
}
