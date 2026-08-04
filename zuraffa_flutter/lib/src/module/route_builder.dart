import 'package:flutter/widgets.dart';

import 'package:zuraffa/zuraffa.dart';

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
typedef ZuraffaRouteBuilder =
    Widget Function(BuildContext context, Object? args);

/// Adapts a Flutter [ZuraffaRouteBuilder] to the engine's platform-agnostic
/// [ZuraffaRouteHandler] (`Object? Function(Object?)`).
///
/// The host (e.g. [ZuraffaAppRunner]) supplies the [BuildContext] at build
/// time; handlers that need it close over it. If [context] is omitted
/// (`null`), the builder is invoked with a `null` context, which is safe
/// only for routes that don't touch the widget tree.
ZuraffaRouteHandler adaptRouteBuilder(
  ZuraffaRouteBuilder builder, {
  BuildContext? context,
}) {
  return (Object? args) => builder(
    context ??
        (throw StateError(
          'ZuraffaRouteBuilder requires a BuildContext. Provide one via '
          'adaptRouteBuilder(context: ...) when registering Flutter routes.',
        )),
    args,
  );
}
