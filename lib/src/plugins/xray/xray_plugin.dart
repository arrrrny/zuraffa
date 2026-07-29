import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../core/api_bridge.dart';

/// Where the x-ray overlay docks on screen.
enum OverlayPosition { topLeft, topRight, bottomLeft, bottomRight }

/// Configuration for [XRayPlugin.enable] / `Zuraffa.enableXRay`.
///
/// Each `bool` toggles one section of the debug overlay. UseCase and
/// catalog data comes from the `api` plugin's bridge; the other sections
/// list elements registered with [XRayPlugin.registerElement].
class XRayConfig {
  final bool useCases;
  final bool repositories;
  final bool dataSources;
  final bool controllers;
  final bool presenters;
  final bool services;
  final bool routes;

  /// Show every endpoint registered with [ZuraffaApiBridge], regardless of
  /// the other flags.
  final bool endpointCatalog;

  final OverlayPosition overlayPosition;

  const XRayConfig({
    this.useCases = true,
    this.repositories = false,
    this.dataSources = false,
    this.controllers = false,
    this.presenters = false,
    this.services = false,
    this.routes = false,
    this.endpointCatalog = true,
    this.overlayPosition = OverlayPosition.bottomRight,
  });
}

/// The kind of a generated Zuraffa element, matching the overlay sections.
enum XRayElementType {
  repository,
  dataSource,
  controller,
  presenter,
  service,
  route,
}

/// A non-UseCase element registered with [XRayPlugin.registerElement].
///
/// [onInvoke] is optional: when present, tapping the element's button in
/// the overlay runs it and shows the returned description (e.g. current
/// state); when absent, the button shows the element's metadata only.
class XRayElement {
  final XRayElementType type;
  final String? domain;
  final String name;
  final FutureOr<String> Function()? onInvoke;

  const XRayElement({
    required this.type,
    required this.name,
    this.domain,
    this.onInvoke,
  });
}

/// Read-only projection of `ApiEndpoint` used by x-ray's widgets.
typedef XRayEndpointInfo = ({
  String method,
  String domain,
  String usecase,
  Map<String, String> params,
  String returns,
  bool isStream,
});

/// Describes a single field of an entity known to x-ray, so the overlay
/// can render a typed form (instead of one raw JSON field) for endpoints
/// whose params are `{'args': '<EntityName>'}`.
class XRayEntityField {
  final String name;

  /// 'String' | 'int' | 'double' | 'bool' | 'DateTime'
  final String type;

  const XRayEntityField({required this.name, required this.type});
}

/// Central registry for the x-ray plugin.
///
/// Process-wide singleton (the same pattern `ZuraffaApiBridge` uses):
/// readable from `Zuraffa.enableXRay()` (no `BuildContext`) and from any
/// widget, with a single source of truth for the whole app.
class XRayPlugin {
  static final XRayPlugin _instance = XRayPlugin._();
  factory XRayPlugin() => _instance;
  XRayPlugin._();

  bool _enabled = false;
  XRayConfig _config = const XRayConfig();

  final Map<String, List<XRayEntityField>> _entitySchemas = {};
  final List<XRayElement> _elements = [];

  /// Bumped whenever [registerElement] / [clearElements] mutates the
  /// registry, so a mounted overlay rebuilds with fresh data.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Rebuild trigger for overlay *content*: fires on element-registry
  /// changes (own [revision]) and on bridge endpoint-catalog changes, so
  /// endpoints registered after the overlay mounts still appear without
  /// waiting for an unrelated rebuild.
  Listenable get contentRevision =>
      Listenable.merge([revision, ZuraffaApiBridge.revision]);

  /// Test hook for the "release mode is a no-op" acceptance case: when set
  /// to `true`, [enable] behaves exactly as if `kReleaseMode` were true.
  /// Never set this in app code.
  @visibleForTesting
  bool debugSimulateReleaseMode = false;

  /// Whether x-ray is active. Always `false` in release builds.
  bool get enabled => _enabled;

  /// The active configuration. Meaningless when [enabled] is `false`.
  XRayConfig get config => _config;

  /// Enable x-ray. No-op in release builds — safe to call unconditionally
  /// from `main()`.
  void enable(XRayConfig config) {
    if (kReleaseMode || debugSimulateReleaseMode) return;
    _enabled = true;
    _config = config;
    // Notify mounted hosts/overlays so late enable() calls take effect
    // without waiting for an unrelated rebuild.
    revision.value++;
    developer.log(
      'XRayPlugin enabled '
      '(useCases: ${config.useCases}, '
      'endpointCatalog: ${config.endpointCatalog})',
      name: 'XRayPlugin',
    );
  }

  /// Disable x-ray (drops the overlay). Mostly useful for tests.
  void disable() {
    _enabled = false;
    revision.value++;
  }

  /// The live endpoint catalog, read straight from [ZuraffaApiBridge] so
  /// x-ray can never drift out of sync with what DTD/VM-Service clients
  /// see via `ext.zuraffa._list`.
  List<XRayEndpointInfo> get registeredEndpoints =>
      ZuraffaApiBridge.getRegisteredEndpoints()
          .map(
            (e) => (
              method: e.method,
              domain: e.domain,
              usecase: e.usecase,
              params: e.params,
              returns: e.returns,
              isStream: e.isStream,
            ),
          )
          .toList();

  /// Invoke a registered endpoint in-process through the api bridge.
  ///
  /// Runs the exact handler `dart:developer` would invoke for an external
  /// VM Service client; only the transport is skipped. See
  /// [ZuraffaApiBridge.invokeLocally] for the rationale.
  Future<developer.ServiceExtensionResponse> invoke(
    String method, {
    Map<String, String> params = const {},
  }) {
    return ZuraffaApiBridge.invokeLocally(method, params);
  }

  // -----------------------------------------------------------------------
  // Element registry (Repositories, DataSources, Controllers, Presenters,
  // Services, Routes sections)
  // -----------------------------------------------------------------------

  /// Register a generated element so its overlay section has a stable,
  /// DTD-findable button. Call from `main()` alongside your
  /// `register*ApiBridge()` functions (or from generated code):
  ///
  /// ```dart
  /// XRayPlugin().registerElement(
  ///   type: XRayElementType.repository,
  ///   domain: 'product',
  ///   name: 'ProductRepository',
  /// );
  /// ```
  void registerElement({
    required XRayElementType type,
    required String name,
    String? domain,
    FutureOr<String> Function()? onInvoke,
  }) {
    _elements.add(
      XRayElement(type: type, name: name, domain: domain, onInvoke: onInvoke),
    );
    revision.value++;
  }

  /// All registered elements of [type], in registration order.
  List<XRayElement> elementsOf(XRayElementType type) =>
      _elements.where((e) => e.type == type).toList(growable: false);

  /// Drop every registered element (keeps enable/config state).
  void clearElements() {
    _elements.clear();
    revision.value++;
  }

  // -----------------------------------------------------------------------
  // Entity schemas for typed param forms
  // -----------------------------------------------------------------------

  /// Register the fields of an entity so x-ray can build a typed form for
  /// endpoints whose params are `{'args': '<EntityName>'}`.
  void registerEntitySchema(String entityName, List<XRayEntityField> fields) {
    _entitySchemas[entityName] = fields;
  }

  /// The field schema for [entityName], or null if unknown.
  List<XRayEntityField>? entityFieldsFor(String entityName) =>
      _entitySchemas[entityName];

  /// Reset all x-ray state. For tests that need a clean slate.
  @visibleForTesting
  void resetForTesting() {
    disable();
    _config = const XRayConfig();
    _entitySchemas.clear();
    _elements.clear();
    revision.value++;
    debugSimulateReleaseMode = false;
  }
}
