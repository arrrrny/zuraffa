import 'package:flutter/widgets.dart';

import '../providers/mock_grocery_provider.dart';

/// Lightweight DI scope exposing the [MockGroceryProvider] to the feature.
///
/// Keeps the camera feature decoupled from *how* the provider is constructed
/// (a real backend provider could be swapped in behind the same interface).
class MockGroceryScope extends InheritedWidget {
  const MockGroceryScope({
    super.key,
    required this.provider,
    required super.child,
  });

  final MockGroceryProvider provider;

  static MockGroceryProvider of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MockGroceryScope>()
          ?.provider ??
      (throw FlutterError('MockGroceryScope missing above $context'));

  @override
  bool updateShouldNotify(MockGroceryScope oldWidget) =>
      provider != oldWidget.provider;
}
