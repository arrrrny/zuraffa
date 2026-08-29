/// Base class for generated route parameters + the controller-facing
/// holder (spec 033 FR-003/FR-004).
///
/// The generated router binds a typed `<Name>RouteParams` instance on every
/// navigation; controllers read it at initialization via
/// `ZfaRouteParams.currentAs<T>()`.
library;

/// Base class of every generated `<Name>RouteParams` class.
class ZfaRouteParams {
  const ZfaRouteParams({
    this.pathParameters = const <String, String>{},
    this.queryParameters = const <String, String>{},
  });

  /// Raw extracted path parameters.
  final Map<String, String> pathParameters;

  /// Raw extracted query parameters.
  final Map<String, String> queryParameters;

  static ZfaRouteParams? _current;

  /// Binds [params] as the currently active route parameters. Called by the
  /// generated route builder on every navigation before the View mounts, so
  /// the associated controller can read the parameters at initialization.
  static void bind(ZfaRouteParams params) {
    _current = params;
  }

  /// Returns the currently bound parameters typed as [T].
  ///
  /// Throws [StateError] when nothing is bound or the bound instance is not
  /// a [T] (e.g. navigating to a route whose params class differs).
  static T currentAs<T extends ZfaRouteParams>() {
    final current = _current;
    if (current == null) {
      throw StateError(
        'No route parameters are bound. ZfaRouteParams.currentAs() must be '
        'called from a controller initialized by the zfa router.',
      );
    }
    if (current is! T) {
      throw StateError(
        'Current route parameters are ${current.runtimeType}, expected $T. '
        'Read the params class matching the active route.',
      );
    }
    return current;
  }

  /// Clears the holder (test isolation / teardown).
  static void reset() {
    _current = null;
  }

  // ------------------------------------------------------------------
  // Typed parse helpers — shared by every generated fromMaps factory.
  // ------------------------------------------------------------------

  /// Parses [key] from [params] as a string (empty when absent).
  static String stringParam(
    Map<String, String> params,
    String key, {
    String fallback = '',
  }) {
    final value = params[key];
    if (value == null) return fallback;
    return value;
  }

  /// Parses [key] from [params] as an int ([fallback] when absent/invalid).
  static int intParam(
    Map<String, String> params,
    String key, {
    int fallback = 0,
  }) {
    return int.tryParse(params[key] ?? '') ?? fallback;
  }

  /// Parses [key] from [params] as a double ([fallback] when absent/invalid).
  static double doubleParam(
    Map<String, String> params,
    String key, {
    double fallback = 0.0,
  }) {
    return double.tryParse(params[key] ?? '') ?? fallback;
  }

  /// Parses [key] from [params] as a bool ('true'/'false'; [fallback]
  /// otherwise).
  static bool boolParam(
    Map<String, String> params,
    String key, {
    bool fallback = false,
  }) {
    final value = params[key];
    if (value == 'true') return true;
    if (value == 'false') return false;
    return fallback;
  }
}
