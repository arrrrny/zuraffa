/// Route builder callback type (platform-agnostic).
///
/// Each entry in [ZuraffaPlugin.routes] maps a route name to a
/// [ZuraffaRouteBuilder]. The builder receives an optional, opaque
/// payload forwarded from the navigation call.
///
/// In a Flutter app, the `zuraffa_flutter` package provides
/// `WidgetRouteBuilder` which is the Flutter-specific version.
typedef ZuraffaRouteBuilder = Object? Function(Object? args);
