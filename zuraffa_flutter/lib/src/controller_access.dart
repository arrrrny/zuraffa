import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:zuraffa_flutter/src/presentation/controller.dart';

/// Flutter-side controller access.
///
/// This restores the `Zuraffa.getController(...)` API that moved out of the
/// pure-Dart `zuraffa` facade with the package split. It lives here because
/// it needs [BuildContext] and [Provider], both Flutter-only.
abstract final class ZuraffaControllerAccess {
  /// Retrieve a [Controller] from the widget tree.
  ///
  /// Use this to access a [Controller] from widgets that are children
  /// of a [CleanViewState].
  ///
  /// Set [listen] to `false` if you don't need to rebuild when the
  /// [Controller] changes (e.g. for event handlers).
  ///
  /// ## Example
  /// ```dart
  /// // In a child widget
  /// final controller = ZuraffaControllerAccess.getController<MyController>(context);
  /// controller.doSomething();
  ///
  /// // Without listening (for callbacks)
  /// onPressed: () {
  ///   final controller = ZuraffaControllerAccess.getController<MyController>(
  ///     context,
  ///     listen: false,
  ///   );
  ///   controller.handleButtonPress();
  /// }
  /// ```
  static Con getController<Con extends Controller>(
    BuildContext context, {
    bool listen = true,
  }) {
    return Provider.of<Con>(context, listen: listen);
  }
}
