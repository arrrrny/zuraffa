import 'package:flutter/widgets.dart';

/// Produces deterministic, semantic [Key]s for every widget the x-ray
/// overlay renders.
///
/// ## Why deterministic keys matter
///
/// The whole point of x-ray is that an agent connected via the Flutter
/// Device Test Driver (DTD) protocol — or any `dart:developer` VM Service
/// client — can predict a widget's key from domain + element name alone,
/// without ever having queried the widget tree first. That means:
///
/// ```dart
/// // An agent that already knows the domain/usecase names (e.g. from the
/// // `ext.zuraffa._list` catalog) can go straight to:
/// await driver.tap(find.byValueKey('xray::usecase::barcode_listing::scanBarcode'));
/// ```
///
/// No UUIDs, no incrementing counters, no `hashCode` of a runtime object —
/// anything non-deterministic would force the agent to re-discover the key
/// on every run, which defeats the purpose.
///
/// ## Key format
///
/// `xray::<elementType>::<domain>::<name>`
///
/// - `elementType` is one of the fixed section identifiers below
///   (`usecase`, `repository`, `datasource`, `controller`, `presenter`,
///   `service`, `route`, `endpoint`).
/// - `domain` is the lower_snake_case domain/entity name (e.g.
///   `barcode_listing`), or omitted (see [endpoint], [controller]) for
///   element types that aren't domain-scoped.
/// - `name` is the exact usecase/repository/etc. name as registered (e.g.
///   the camelCase `usecase` field from [ApiEndpoint]).
///
/// All segments are used verbatim — no sanitization — because the values
/// are expected to already be safe Dart identifiers coming from generated
/// code. If you need to feed in freeform strings, sanitize them before
/// calling into this class.
class XRayElementKey {
  XRayElementKey._();

  static const String _prefix = 'xray';

  /// `xray::usecase::<domain>::<useCaseName>`
  ///
  /// e.g. `XRayElementKey.useCase('barcode_listing', 'scanBarcode')`
  /// -> `Key('xray::usecase::barcode_listing::scanBarcode')`
  static Key useCase(String domain, String useCaseName) =>
      Key('$_prefix::usecase::$domain::$useCaseName');

  /// `xray::repository::<domain>::<repoName>`
  static Key repository(String domain, String repoName) =>
      Key('$_prefix::repository::$domain::$repoName');

  /// `xray::datasource::<domain>::<dsName>`
  static Key dataSource(String domain, String dsName) =>
      Key('$_prefix::datasource::$domain::$dsName');

  /// `xray::controller::<controllerName>`
  ///
  /// Controllers aren't domain-scoped in Zuraffa's DI registry the way
  /// UseCases are, so this key has no domain segment.
  static Key controller(String controllerName) =>
      Key('$_prefix::controller::$controllerName');

  /// `xray::presenter::<domain>::<presenterName>`
  static Key presenter(String domain, String presenterName) =>
      Key('$_prefix::presenter::$domain::$presenterName');

  /// `xray::service::<serviceName>`
  static Key service(String serviceName) =>
      Key('$_prefix::service::$serviceName');

  /// `xray::route::<routeName>`
  static Key route(String routeName) => Key('$_prefix::route::$routeName');

  /// `xray::endpoint::<method>`
  ///
  /// Used for the flat "Catalog" section, which is keyed on the full
  /// `ext.zuraffa.<domain>.<usecase>` method string rather than on a
  /// domain/name pair — the method string is already the unique,
  /// deterministic identifier the `api` bridge assigned it.
  static Key endpoint(String method) => Key('$_prefix::endpoint::$method');

  /// `xray::section::<sectionId>`
  ///
  /// Key for a whole collapsible section container (e.g. the "UseCases"
  /// panel itself), useful for an agent that wants to scroll a section
  /// into view before looking for a child button.
  static Key section(String sectionId) =>
      Key('$_prefix::section::$sectionId');

  /// `xray::overlay::root`
  ///
  /// The single, fixed key for the overlay's root widget, so an agent (or
  /// a test) can assert on overlay presence without knowing about any
  /// specific section.
  ///
  /// Note: uses [ValueKey] directly (not the `Key(...)` factory used
  /// elsewhere in this class) because `Key(...)` is a non-const factory
  /// constructor — it can't be used to build a `static const` value.
  /// `ValueKey`'s constructor is `const`, so this is the one place these
  /// two fixed keys are spelled out as literals rather than built through
  /// a helper.
  static const Key overlayRoot = ValueKey<String>('$_prefix::overlay::root');

  /// `xray::overlay::close`
  static const Key overlayClose = ValueKey<String>(
    '$_prefix::overlay::close',
  );

  /// `xray::form::submit::<method>`
  ///
  /// Key for the submit button of the inline parameter-entry form shown
  /// for endpoints that take non-empty params.
  static Key formSubmit(String method) =>
      Key('$_prefix::form::submit::$method');

  /// `xray::form::field::<method>::<paramName>`
  static Key formField(String method, String paramName) =>
      Key('$_prefix::form::field::$method::$paramName');
}
