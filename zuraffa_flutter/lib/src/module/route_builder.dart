import 'package:flutter/widgets.dart';

/// Flutter-specific route builder — builds a [Widget] from route arguments.
///
/// This is the Flutter counterpart to the platform-agnostic
/// [ZuraffaRouteBuilder] from the `zuraffa` package. Use this in
/// [ZuraffaPlugin.routes] when building Flutter UIs.
///
/// ```dart
/// Widget _buildProductPage(BuildContext context, Object? args) {
///   final productId = (args as Map<String, dynamic>?)?['id'] as String?;
///   return ProductDetailPage(productId: productId);
/// }
/// ```
typedef FlutterRouteBuilder = Widget Function(BuildContext context, Object? args);
