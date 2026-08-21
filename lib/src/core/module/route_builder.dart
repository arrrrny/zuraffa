/// Route handler callback type (platform-agnostic).
///
/// Each entry in [ZuraffaPlugin.routes] maps a route name to a
/// [ZuraffaRouteHandler]. The handler receives an optional, opaque
/// payload forwarded from the navigation call.
///
/// This is the pure-Dart core's route callback. Flutter consumers use
/// `ZuraffaRouteBuilder` (from the `zuraffa_flutter` package), which is
/// the Widget-returning, BuildContext-aware counterpart.
typedef ZuraffaRouteHandler = Object? Function(Object? args);
