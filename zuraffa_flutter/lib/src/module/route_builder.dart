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
/// The host (e.g. [ZuraffaAppRunner]) must pass the runtime [BuildContext]
/// as part of the [args] payload. The payload should be a [Map] with a
/// '_context' key containing the [BuildContext], and an optional 'args' key
/// for route-specific arguments.
///
/// If the payload is not a Map or lacks '_context', an error is thrown.
ZuraffaRouteHandler adaptRouteBuilder(ZuraffaRouteBuilder builder) {
  return (Object? args) {
    if (args is! Map<String, dynamic>) {
      throw StateError(
        'ZuraffaRouteBuilder requires a Map payload with "_context" key. '
        'Received: ${args.runtimeType}',
      );
    }
    final context = args['_context'] as BuildContext?;
    if (context == null) {
      throw StateError(
        'ZuraffaRouteBuilder requires a BuildContext in the payload. '
        'Pass it via {"_context": context, "args": ...}',
      );
    }
    final routeArgs = args['args'];
    return builder(context, routeArgs);
  };
}
