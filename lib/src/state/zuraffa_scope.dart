import 'package:flutter/widgets.dart';
import 'zuraffa_container.dart';
import 'provider_base.dart';

/// ZuraffaScope - Root widget that provides access to the container
///
/// Wrap your app with ZuraffaScope to enable state management.
///
/// Example:
/// ```dart
/// void main() {
///   runApp(
///     ZuraffaScope(
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
class ZuraffaScope extends InheritedWidget {
  final ZuraffaContainer container;

  /// Create a ZuraffaScope with optional overrides
  ZuraffaScope({
    Key? key,
    List<ProviderOverride> overrides = const [],
    required Widget child,
  })  : container = overrides.isEmpty
            ? ZuraffaContainer()
            : ZuraffaContainerWithOverrides(overrides: overrides),
        super(key: key, child: child);

  /// Create a ZuraffaScope with a custom container
  ZuraffaScope.withContainer({
    Key? key,
    required this.container,
    required Widget child,
  }) : super(key: key, child: child);

  /// Get the container from the nearest ZuraffaScope
  static ZuraffaContainer of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ZuraffaScope>();

    if (scope == null) {
      throw StateError(
        'No ZuraffaScope found in widget tree.\n'
        'Wrap your app with ZuraffaScope:\n'
        '  ZuraffaScope(\n'
        '    child: MyApp(),\n'
        '  )',
      );
    }

    return scope.container;
  }

  /// Get the container from the nearest ZuraffaScope (nullable)
  static ZuraffaContainer? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ZuraffaScope>();
    return scope?.container;
  }

  @override
  bool updateShouldNotify(ZuraffaScope oldWidget) {
    return container != oldWidget.container;
  }
}

/// Extension on BuildContext for convenient access to container
extension ZuraffaScopeExtension on BuildContext {
  /// Get the ZuraffaContainer from the nearest ZuraffaScope
  ZuraffaContainer get container => ZuraffaScope.of(this);
}
