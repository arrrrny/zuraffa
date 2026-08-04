import 'package:flutter/widgets.dart';

/// Function signature for building a route page widget.
///
/// Each entry in [ZuraffaPlugin.routes] maps a route name to a
/// [ZuraffaRouteBuilder]. When the host application navigates to
/// that route, the framework calls the builder with:
///
/// - [context] -- the [BuildContext] at the point of navigation.
/// - [args] -- an optional, opaque payload forwarded from the
///   navigation call.
///
/// ```dart
/// Widget _buildProductPage(BuildContext context, Object? args) {
///   final productId = (args as Map<String, dynamic>?)?['id'] as String?;
///   return ProductDetailPage(productId: productId);
/// }
/// ```
typedef ZuraffaRouteBuilder = Widget Function(BuildContext context, Object? args);
