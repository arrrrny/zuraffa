import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:provider/provider.dart';

import '../core/loggable.dart';
import 'controller.dart';

/// A Clean Architecture View.
///
/// [CleanView] is a [StatefulWidget] that serves as the base class for
/// all views (screens/pages) in the application. It integrates with
/// [Controller] for state management and business logic coordination.
///
/// ## Features
/// - Automatic Controller lifecycle management
/// - Provider integration for dependency injection
/// - Route awareness for navigation callbacks
/// - Built-in global key for Controller access to context/state
///
/// ## Example
/// ```dart
/// class ProductPage extends CleanView {
///   final String productId;
///
///   const ProductPage({
///     required this.productId,
///     super.key,
///     super.routeObserver,
///   });
///
///   @override
///   State<ProductPage> createState() => _ProductPageState();
/// }
///
/// class _ProductPageState
///     extends CleanViewState<ProductPage, ProductController, ProductState> {
///   _ProductPageState() : super(ProductController());
///
///   @override
///   Widget get view {
///     return Scaffold(
///       key: globalKey, // Important: use globalKey on root widget
///       appBar: AppBar(title: Text('Product')),
///       body: ControlledWidgetBuilder<ProductController>(
///         builder: (context, controller) {
///           if (controller.viewState.isLoading) {
///             return const CircularProgressIndicator();
///           }
///           return ProductDetails(product: controller.viewState.product);
///         },
///       ),
///     );
///   }
///
///   @override
///   void onViewStateChanged(ProductState state) {
///     if (state.shouldNavigateToSuccess) {
///       context.go('/success');
///     }
///   }
///
///   @override
///   void onInitState() {
///     super.onInitState();
///     controller.loadProduct(widget.productId);
///   }
/// }
/// ```
abstract class CleanView extends StatefulWidget {
  /// Optional [RouteObserver] for route awareness.
  ///
  /// If provided, the Controller will receive callbacks for route events
  /// (push, pop, etc.) via [RouteAware].
  final RouteObserver<ModalRoute<void>>? routeObserver;

  const CleanView({super.key, this.routeObserver});
}

/// The state for a [CleanView].
///
/// [CleanViewState] manages the lifecycle of a [Controller] and provides
/// integration with Flutter's widget lifecycle, Provider for state management,
/// and route observation.
///
/// ## Key Features
/// - Automatic Controller initialization and disposal
/// - Global key for Controller access to BuildContext and State
/// - Provider integration for [ControlledWidgetBuilder]
/// - Route awareness via [RouteObserver]
///
/// ## Usage
/// 1. Extend this class with your Page and Controller types
/// 2. Pass the Controller instance to super constructor
/// 3. Override `view` getter to build your UI
/// 4. Use `globalKey` on your root widget (usually Scaffold)
/// 5. Use [ControlledWidgetBuilder] for widgets that need Controller access
///
/// ## Type Parameters
/// - `P` — The [CleanView] subclass (your page widget)
/// - `Con` — The [Controller] subclass
/// - `S` — The state type managed by your controller's [StatefulController]
///   mixin. Use `void` if your controller doesn't use [StatefulController].
///
/// ## Example
/// ```dart
/// // With StatefulController — typed state changes
/// class _ProductPageState
///     extends CleanViewState<ProductPage, ProductController, ProductState> {
///   _ProductPageState() : super(ProductController());
///
///   @override
///   Widget get view {
///     return Scaffold(
///       key: globalKey,
///       body: ControlledWidgetBuilder<ProductController>(
///         builder: (context, controller) {
///           return Text(controller.viewState.message);
///         },
///       ),
///     );
///   }
///
///   @override
///   void onViewStateChanged(ProductState state) {
///     if (state.isSuccess) context.go('/success');
///   }
/// }
///
/// // Without StatefulController — use void
/// class _SimplePageState
///     extends CleanViewState<SimplePage, SimpleController, void> {
///   _SimplePageState() : super(SimpleController());
///
///   @override
///   Widget get view => Scaffold(key: globalKey, body: Text('Hello'));
/// }
/// ```
abstract class CleanViewState<P extends CleanView, Con extends Controller, S>
    extends State<P>
    with Loggable {
  /// The Controller for this view.
  ///
  /// Access this to call Controller methods or read state.
  @protected
  final Con controller;

  /// Global key for the root widget.
  ///
  /// **Important**: Use this key on your root widget (usually Scaffold)
  /// to enable the Controller to access BuildContext and State.
  ///
  /// Example:
  /// ```dart
  /// Scaffold(
  ///   key: globalKey,
  ///   body: ...,
  /// )
  /// ```
  final GlobalKey<State<StatefulWidget>> globalKey =
      GlobalKey<State<StatefulWidget>>();

  /// Create a [CleanViewState] with the given [controller].
  CleanViewState(this.controller) {
    controller.initController(globalKey);
  }

  /// Override this to build your view.
  ///
  /// This is the main build method for your page. Use [globalKey] on
  /// the root widget and [ControlledWidgetBuilder] for widgets that
  /// need to react to Controller state changes.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Widget get view {
  ///   return Scaffold(
  ///     key: globalKey,
  ///     appBar: AppBar(title: const Text('My Page')),
  ///     body: ControlledWidgetBuilder<MyController>(
  ///       builder: (context, controller) {
  ///         return Text(controller.state.data);
  ///       },
  ///     ),
  ///   );
  /// }
  /// ```
  Widget get view;

  /// Called when the state is initialized.
  ///
  /// Override this method to perform initialization tasks when the
  /// state is first created, after the controller has been initialized.
  ///
  /// Remember to call `super.onInitState()` when overriding.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void onInitState() {
  ///   super.onInitState();
  ///   controller.loadData();
  /// }
  /// ```
  @protected
  void onInitState() {}

  /// Called when the controller state changes.
  ///
  /// This method is called whenever the controller calls [Controller.refreshUI]
  /// and the controller uses [StatefulController]<[S]>. The new state is
  /// passed with full type safety.
  ///
  /// Override this to handle side effects (navigation, showing dialogs, etc.)
  /// based on state changes.
  ///
  /// **Note**: This callback only fires when the controller uses
  /// [StatefulController]<[S]>. If your controller doesn't use
  /// [StatefulController], this method is never called.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void onViewStateChanged(ProductState state) {
  ///   if (state.isSuccess) {
  ///     context.go('/success');
  ///   }
  ///   if (state.error != null) {
  ///     ScaffoldMessenger.of(context).showSnackBar(
  ///       SnackBar(content: Text(state.error!.message)),
  ///     );
  ///   }
  /// }
  /// ```
  @protected
  void onViewStateChanged(S state) {}

  // ============================================================
  // Flutter Lifecycle
  // ============================================================

  @override
  @mustCallSuper
  void initState() {
    super.initState();
    logger.fine('initState');

    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(controller);

    // Notify controller
    controller.onInitState();

    // Setup listener for state changes to trigger onViewStateChanged
    controller.addListener(_handleStateChange);

    // Call the overridable onInitState method
    onInitState();
  }

  void _handleStateChange() {
    if (!mounted) return;

    if (controller is StatefulController<S>) {
      onViewStateChanged((controller as StatefulController<S>).viewState);
    }
  }

  @override
  @mustCallSuper
  void didChangeDependencies() {
    super.didChangeDependencies();
    logger.fine('didChangeDependencies');

    // Subscribe to route events if observer is provided
    if (widget.routeObserver != null) {
      final route = ModalRoute.of(context);
      if (route != null) {
        widget.routeObserver!.subscribe(controller, route);
        logger.fine('Subscribed to route observer');
      }
    }

    // Notify controller
    controller.onDidChangeDependencies();
  }

  @override
  @nonVirtual
  Widget build(BuildContext context) {
    // Wrap in ChangeNotifierProvider for ControlledWidgetBuilder access
    return ChangeNotifierProvider<Con>.value(value: controller, child: view);
  }

  @override
  @mustCallSuper
  void deactivate() {
    logger.fine('deactivate');
    controller.onDeactivated();
    super.deactivate();
  }

  @override
  @mustCallSuper
  void reassemble() {
    logger.fine('reassemble');
    controller.onReassembled();
    super.reassemble();
  }

  @override
  @mustCallSuper
  void dispose() {
    logger.fine('dispose');

    controller.removeListener(_handleStateChange);

    // Unregister from app lifecycle events
    WidgetsBinding.instance.removeObserver(controller);

    // Unsubscribe from route events
    if (widget.routeObserver != null) {
      widget.routeObserver!.unsubscribe(controller);
    }

    // Notify controller and dispose
    controller.onDisposed();

    super.dispose();
  }
}
