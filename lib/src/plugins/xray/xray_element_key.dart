import 'package:flutter/widgets.dart';

/// Produces deterministic, semantic [Key]s for every widget the x-ray
/// overlay renders.
///
/// ## Why deterministic keys matter
///
/// The whole point of x-ray is that an agent connected via the Flutter
/// Device Test Driver (DTD) protocol — or any `dart:developer` VM Service
/// client — can predict a widget's key from the domain + element name
/// alone, without inspecting the widget tree first:
///
/// ```dart
/// await driver.tap(
///   find.byValueKey('xray::usecase::barcode_listing::scanBarcode'),
/// );
/// ```
///
/// No UUIDs, no counters, no `hashCode` — anything non-deterministic
/// would force the agent to re-discover keys on every run.
///
/// ## Key format
///
/// `xray::<elementType>::<domain>::<name>`
///
/// - `elementType`: one of `usecase`, `repository`, `datasource`,
///   `controller`, `presenter`, `service`, `route`, `endpoint`.
/// - `domain`: the lower_snake_case domain/entity name; omitted for
///   element types that are not domain-scoped ([controller], [service],
///   [route], [endpoint]).
/// - `name`: the exact name as registered (e.g. the camelCase `usecase`
///   field of an `ApiEndpoint`).
///
/// Segments are used verbatim; values are expected to already be safe
/// Dart identifiers coming from generated code.
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
  /// Keys the flat "Catalog" section by the full
  /// `ext.zuraffa.<domain>.<usecase>` method string — already the unique,
  /// deterministic identifier the `api` bridge assigned.
  static Key endpoint(String method) => Key('$_prefix::endpoint::$method');

  /// `xray::section::<sectionId>` — a whole collapsible section panel.
  static Key section(String sectionId) => Key('$_prefix::section::$sectionId');

  /// `xray::overlay::root` — fixed key of the overlay's root widget.
  static const Key overlayRoot = ValueKey<String>('$_prefix::overlay::root');

  /// `xray::overlay::close` — fixed key of the close button.
  static const Key overlayClose = ValueKey<String>('$_prefix::overlay::close');

  /// `xray::overlay::launcher` — fixed key of the collapsed launcher that
  /// re-opens the overlay after dismissal.
  static const Key overlayLauncher = ValueKey<String>(
    '$_prefix::overlay::launcher',
  );

  /// `xray::form::submit::<method>` — submit button of an inline param form.
  static Key formSubmit(String method) =>
      Key('$_prefix::form::submit::$method');

  /// `xray::form::field::<method>::<paramName>` — one form input field.
  static Key formField(String method, String paramName) =>
      Key('$_prefix::form::field::$method::$paramName');
}
