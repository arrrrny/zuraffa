import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kReleaseMode;

import '../../core/api_bridge.dart';

/// Where the collapsed x-ray launcher button docks when the overlay itself
/// is closed.
enum OverlayPosition { topLeft, topRight, bottomLeft, bottomRight }

/// Configuration for [XRayPlugin.enable] / `Zuraffa.enableXRay`.
///
/// Each `bool` toggles one grid section in [XRayOverlay]. Sections default
/// mostly to `false` because most apps only want to drive UseCases from the
/// overlay/DTD — the other sections are opt-in verbosity.
class XRayConfig {
  final bool useCases;
  final bool repositories;
  final bool dataSources;
  final bool controllers;
  final bool presenters;
  final bool services;
  final bool routes;

  /// Show every endpoint registered with [ZuraffaApiBridge], regardless of
  /// which of the flags above are set. This is the fastest way to see
  /// "everything the api bridge knows about" without curating sections.
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

/// Read-only projection of [ApiEndpoint] used by x-ray's widgets.
///
/// Kept as its own record type (rather than exporting `ApiEndpoint`
/// directly into widget code) so that x-ray's UI layer never depends on
/// `api_bridge.dart` internals beyond [ZuraffaApiBridge.getRegisteredEndpoints].
/// `params` is included (in addition to the fields named in the original
/// interface sketch) because [XRayButton] needs it to decide whether to
/// call an endpoint directly or open the inline param form first.
typedef XRayEndpointInfo = ({
  String method,
  String domain,
  String usecase,
  Map<String, String> params,
  String returns,
  bool isStream,
});

/// Describes a single field of an entity known to x-ray.
///
/// Used by [XRayButton] to render a typed form when an endpoint takes an
/// entity param (e.g. `Todo` or `Product`), instead of showing a single
/// raw-text field for the JSON blob `args`.
class XRayEntityField {
  final String name;
  final String type; // 'String' | 'int' | 'double' | 'bool' | 'DateTime'

  const XRayEntityField({required this.name, required this.type});
}

/// Central registry for the x-ray plugin.
///
/// A process-wide singleton (matching the pattern `ZuraffaApiBridge` and
/// the other Zuraffa plugins use) rather than something threaded through
/// the widget tree, because:
///
/// - It must be readable from `Zuraffa.enableXRay()` (a static method, no
///   `BuildContext` available) as well as from widgets deep in the tree.
/// - Its state (`enabled`, `config`) is a single source of truth for the
///   whole app, not something that should vary by subtree.
class XRayPlugin {
  static final XRayPlugin _instance = XRayPlugin._();
  factory XRayPlugin() => _instance;
  XRayPlugin._();

  bool _enabled = false;
  XRayConfig _config = const XRayConfig();

  /// Registered entity field schemas, keyed by entity name (e.g. "Todo").
  final Map<String, List<XRayEntityField>> _entitySchemas = {};

  /// Register the fields of a Zorphy entity so x-ray can build typed forms.
  ///
  /// Call this alongside your `register*ApiBridge()` functions:
  ///
  /// ```dart
  /// XRayPlugin().registerEntitySchema(
  ///   'Todo',
  ///   [
  ///     const XRayEntityField(name: 'id', type: 'int'),
  ///     const XRayEntityField(name: 'title', type: 'String'),
  ///     const XRayEntityField(name: 'isCompleted', type: 'bool'),
  ///     const XRayEntityField(name: 'createdAt', type: 'DateTime'),
  ///   ],
  /// );
  /// ```
  void registerEntitySchema(
    String entityName,
    List<XRayEntityField> fields,
  ) {
    _entitySchemas[entityName] = fields;
  }

  /// Look up the field schema for [entityName], or null if unknown.
  List<XRayEntityField>? entityFieldsFor(String entityName) =>
      _entitySchemas[entityName];

  /// Whether the overlay/DTD keys are active. Always `false` in release
  /// builds — see [enable].
  bool get enabled => _enabled;

  /// The active configuration. Meaningless when [enabled] is `false`.
  XRayConfig get config => _config;

  /// Enable x-ray.
  ///
  /// No-op in release builds ([kReleaseMode]) — x-ray is a debug/profile
  /// tool only, mirroring the release-mode guard every generated api
  /// bridge already has. This means `Zuraffa.enableXRay(...)` is always
  /// safe to leave in `main()` unconditionally; it simply does nothing
  /// once the app is built for release.
  void enable(XRayConfig config) {
    if (kReleaseMode) return;
    _enabled = true;
    _config = config;
    developer.log(
      'XRayPlugin enabled '
      '(useCases: ${config.useCases}, endpointCatalog: ${config.endpointCatalog})',
      name: 'XRayPlugin',
    );
  }

  /// Disable x-ray and drop the overlay. Mainly useful for tests that need
  /// a clean slate between cases, or an in-app "exit x-ray mode" action.
  void disable() {
    _enabled = false;
  }

  /// The current endpoint catalog, as reported by [ZuraffaApiBridge].
  ///
  /// X-Ray never maintains its own copy of this list — it always reads
  /// live from the api bridge so it can never drift out of sync with what
  /// DTD/VM-Service clients actually see via `ext.zuraffa._list`.
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

  /// Endpoints for a given domain-scoped section (UseCases, Repositories,
  /// DataSources currently all share the same `ext.zuraffa.<domain>.<name>`
  /// registration shape via the `api` plugin, so they're read from the
  /// same catalog and simply filtered/labelled per section by the caller).
  List<XRayEndpointInfo> endpointsForDomain(String domain) =>
      registeredEndpoints.where((e) => e.domain == domain).toList();

  /// Invoke a registered endpoint in-process and return its decoded
  /// `ServiceExtensionResponse`.
  ///
  /// ## Why in-process instead of a VM-Service round trip
  ///
  /// `ZuraffaApiBridge.registerEndpoint` registers each handler with
  /// `dart:developer`'s `registerExtension`, which is designed for an
  /// *external* VM Service client (DevTools, DTD, a driver test) to call
  /// over the VM Service protocol. That registration is what makes an
  /// external agent able to find and call the extension — x-ray does not
  /// touch or duplicate that path.
  ///
  /// But the x-ray overlay button lives *inside the same isolate* as the
  /// handler it wants to call. Round-tripping through a VM Service
  /// websocket connection back to itself would mean either adding a new
  /// package dependency (`package:vm_service`) or hand-rolling VM Service
  /// JSON-RPC framing — both of which would mean re-implementing (a
  /// version of) the RPC layer the `api` plugin already owns, which the
  /// spec explicitly rules out.
  ///
  /// Instead, [ZuraffaApiBridge] keeps a lightweight in-process handler
  /// registry alongside its metadata catalog (see
  /// `ZuraffaApiBridge.invokeLocally`), and x-ray calls that directly. The
  /// handler function itself — parameter deserialization, use case
  /// invocation, `Result` serialization — is exactly the same function
  /// object that would run if a real VM Service client had called the
  /// extension; only the transport is skipped. External DTD/VM-Service
  /// access to the exact same endpoints is unaffected and keeps working
  /// through the normal extension registration.
  Future<developer.ServiceExtensionResponse> invoke(
    String method, {
    Map<String, String> params = const {},
  }) {
    return ZuraffaApiBridge.invokeLocally(method, params);
  }
}
