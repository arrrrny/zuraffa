import 'package:flutter/material.dart' show ThemeData, GlobalKey, NavigatorState;

import 'package:zuraffa/zuraffa.dart';

/// Plugin that wires Flutter UI services into the [ZuraffaEngine].
///
/// Register this plugin with the engine to enable UI-related features
/// such as theme management, navigation, and xray bridge integration.
///
/// ## Usage
///
/// ```dart
/// final engine = ZuraffaEngine()
///   ..register(ZuraffaFlutterPlugin())
///   ..register(MyFeaturePlugin());
/// await engine.bootstrap();
/// runApp(ZuraffaAppRunner(engine: engine));
/// ```
///
/// This plugin is optional — pure Dart apps (CLIs, servers, MCP agents)
/// simply omit it.
class ZuraffaFlutterPlugin extends ZuraffaPlugin {
  @override
  String get pluginId => 'zuraffa.flutter';

  /// Optional custom theme data to register in the DI container.
  final ThemeData? theme;

  /// Optional custom navigation key for imperative navigation.
  final GlobalKey<NavigatorState>? navigatorKey;

  const ZuraffaFlutterPlugin({
    this.theme,
    this.navigatorKey,
  });

  @override
  void registerDependencies(ZuraffaDIContainer di) {
    // Register theme if provided, so feature plugins can access it.
    if (theme != null) {
      di.registerInstance<ThemeData>(theme!);
    }
    if (navigatorKey != null) {
      di.registerInstance<GlobalKey<NavigatorState>>(navigatorKey!);
    }
  }

  @override
  void onInit(ZuraffaDIContainer di) {
    // Future: initialize xray bridge server, platform layout resolver, etc.
    // For now this is a hook point for when those services are ready.
  }

  @override
  Map<String, ZuraffaRouteBuilder> get routes => const {};
}
