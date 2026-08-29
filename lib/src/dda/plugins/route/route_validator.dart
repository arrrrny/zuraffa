/// Build-time validation for `@Route` / `@ZfaRoute` annotations (FR-006).
///
/// The validator runs AFTER annotation collection and BEFORE any file is
/// written: every misconfiguration must fail the build with an actionable
/// error instead of surfacing as a runtime navigation failure.
library;

/// Every error category the route build can fail with (spec FR-006).
enum RouteValidationErrorCode {
  /// Two routes declared the same path.
  duplicatePath,

  /// Two routes declared the same explicit or derived name.
  duplicateName,

  /// A route's `parent` references a route that does not exist.
  missingParent,

  /// A route's `parent` resolves to a route that is not `isShell`.
  parentNotShell,

  /// `@Route` placed on something that is not a View-like class.
  nonViewTarget,

  /// A path/query parameter type outside the supported set.
  unsupportedParamType,

  /// A redirect rule whose target path matches no declared route.
  danglingRedirectTarget,

  /// Routes exist but the project does not depend on `go_router`.
  goRouterMissing,
}

/// A single actionable validation failure.
class RouteValidationError {
  const RouteValidationError({
    required this.code,
    required this.message,
    this.filePath,
    this.line,
  });

  final RouteValidationErrorCode code;

  /// Human-readable, actionable message naming the offending classes/paths.
  final String message;

  /// Source file of the offending annotation, when known.
  final String? filePath;

  /// Line of the offending annotation, when known.
  final int? line;

  @override
  String toString() =>
      '$message${filePath != null ? ' ($filePath${line != null ? ':$line' : ''})' : ''}';
}

/// Public snapshot of one collected route (what the validator and generator
/// operate on).
class RouteEntryInfo {
  const RouteEntryInfo({
    required this.path,
    required this.name,
    required this.className,
    required this.importUri,
    this.deepLinkAware = false,
    this.isShell = false,
    this.parent,
    this.queryParameters = const {},
    this.pathParameters = const {},
    this.middleware = const [],
    this.filePath,
    this.line,
  });

  /// Declared route path, e.g. `/products/:id`.
  final String path;

  /// Route name (explicit or derived from the class name).
  final String name;

  /// Annotated View class name, e.g. `ProductDetailView`.
  final String className;

  /// Import URI of the file declaring the View.
  final String importUri;

  final bool deepLinkAware;

  /// Whether this route is a shell whose View renders around its children.
  final bool isShell;

  /// Raw `parent` reference — a route NAME (`'dashboard'`) or route PATH
  /// (`'/dashboard'`). Legacy `parentPath` values are path references.
  final String? parent;

  /// Declared query parameter types, e.g. `{'q': 'String', 'page': 'int'}`.
  final Map<String, String> queryParameters;

  /// Declared path parameter types, e.g. `{'id': 'int'}`.
  final Map<String, String> pathParameters;

  /// Guard class names applied before route activation.
  final List<String> middleware;

  final String? filePath;
  final int? line;
}

/// Public snapshot of one collected redirect rule.
class RedirectRuleInfo {
  const RedirectRuleInfo({
    required this.from,
    required this.to,
    this.filePath,
    this.line,
  });

  final String from;
  final String to;
  final String? filePath;
  final int? line;
}

/// A `@Route` annotation the scanner collected but could not accept as a
/// route (non-View class, method target, missing path, malformed redirect).
class NonViewTargetInfo {
  const NonViewTargetInfo({
    required this.className,
    required this.reason,
    this.filePath,
    this.line,
  });

  /// The offending element's name (class or Class.method).
  final String className;

  /// Why the annotation was rejected — used verbatim as the error message.
  final String reason;

  final String? filePath;
  final int? line;
}

/// Validates collected route metadata. Pure: data in, errors out.
class RouteValidator {
  /// The only parameter types generated `RouteParams` support.
  static const Set<String> supportedParamTypes = {
    'String',
    'int',
    'double',
    'bool',
  };

  /// Resolves a `parent` reference (route name or path) to the parent route's
  /// PATH, or null when no route matches.
  ///
  /// Accepted forms: exact route name (`'dashboard'`), exact path
  /// (`'/dashboard'`), and slash-less path (`'dashboard'` matching
  /// `/dashboard` when no route is NAMED `dashboard`).
  static String? resolveParentPath(String ref, List<RouteEntryInfo> routes) {
    final normalizedRef = _stripSlashes(ref);
    for (final route in routes) {
      if (route.name == ref) return route.path;
    }
    for (final route in routes) {
      if (_stripSlashes(route.path) == normalizedRef) return route.path;
    }
    return null;
  }

  /// Validate all collected metadata. Empty list = build may proceed.
  List<RouteValidationError> validate({
    required List<RouteEntryInfo> routes,
    required List<RedirectRuleInfo> redirects,
    required List<NonViewTargetInfo> nonViewTargets,
    required Set<String> pubspecDeps,
  }) {
    final errors = <RouteValidationError>[];

    // ── Per-annotation problems (non-View targets, malformed annotations) ──
    for (final target in nonViewTargets) {
      errors.add(
        RouteValidationError(
          code: RouteValidationErrorCode.nonViewTarget,
          message:
              '@Route on "${target.className}" is not a valid route target: '
              '${target.reason}. Annotate View classes '
              '(names ending in View/Shell/Page/Screen) only.',
          filePath: target.filePath,
          line: target.line,
        ),
      );
    }

    // ── go_router precondition ──
    if (routes.isNotEmpty && !pubspecDeps.contains('go_router')) {
      errors.add(
        const RouteValidationError(
          code: RouteValidationErrorCode.goRouterMissing,
          message:
              'Routes were annotated but this project does not depend on '
              'go_router — the generated zfa_router.g.dart would not compile. '
              'Add go_router to your pubspec.yaml dependencies.',
        ),
      );
    }

    // ── Duplicate paths ──
    final byPath = <String, List<RouteEntryInfo>>{};
    for (final route in routes) {
      byPath.putIfAbsent(route.path, () => []).add(route);
    }
    for (final entry in byPath.entries) {
      if (entry.value.length > 1) {
        final classes = entry.value.map((r) => r.className).join('", "');
        errors.add(
          RouteValidationError(
            code: RouteValidationErrorCode.duplicatePath,
            message:
                'Duplicate route path "${entry.key}" — declared by '
                '"$classes". Remove the duplicate @Route annotation or give '
                'one of the routes a different path.',
          ),
        );
      }
    }

    // ── Duplicate names ──
    final byName = <String, List<RouteEntryInfo>>{};
    for (final route in routes) {
      byName.putIfAbsent(route.name, () => []).add(route);
    }
    for (final entry in byName.entries) {
      if (entry.value.length > 1) {
        final classes = entry.value.map((r) => r.className).join('", "');
        errors.add(
          RouteValidationError(
            code: RouteValidationErrorCode.duplicateName,
            message:
                'Duplicate route name "${entry.key}" — declared by '
                '"$classes". Give one of the routes an explicit unique name.',
          ),
        );
      }
    }

    // ── Unsupported parameter types ──
    for (final route in routes) {
      for (final entry in route.pathParameters.entries) {
        if (!supportedParamTypes.contains(entry.value)) {
          errors.add(
            RouteValidationError(
              code: RouteValidationErrorCode.unsupportedParamType,
              message:
                  'Unsupported path parameter type "${entry.value}" for '
                  '"${entry.key}" on route "${route.path}" (${route.className}). '
                  'Supported types: ${supportedParamTypes.join(', ')}.',
              filePath: route.filePath,
              line: route.line,
            ),
          );
        }
      }
      for (final entry in route.queryParameters.entries) {
        if (!supportedParamTypes.contains(entry.value)) {
          errors.add(
            RouteValidationError(
              code: RouteValidationErrorCode.unsupportedParamType,
              message:
                  'Unsupported query parameter type "${entry.value}" for '
                  '"${entry.key}" on route "${route.path}" (${route.className}). '
                  'Supported types: ${supportedParamTypes.join(', ')}.',
              filePath: route.filePath,
              line: route.line,
            ),
          );
        }
      }
    }

    // ── Parent resolution ──
    for (final route in routes) {
      final ref = route.parent;
      if (ref == null) continue;
      final parentPath = resolveParentPath(ref, routes);
      if (parentPath == null) {
        errors.add(
          RouteValidationError(
            code: RouteValidationErrorCode.missingParent,
            message:
                'Route "${route.path}" (${route.className}) references parent '
                '"$ref", but no route with that name or path exists. Declare '
                'the parent with @Route(path: ..., isShell: true) first.',
            filePath: route.filePath,
            line: route.line,
          ),
        );
      } else {
        final parentRoute = routes.firstWhere((r) => r.path == parentPath);
        if (!parentRoute.isShell) {
          errors.add(
            RouteValidationError(
              code: RouteValidationErrorCode.parentNotShell,
              message:
                  'Route "${route.path}" (${route.className}) uses parent '
                  '"$ref", but "${parentRoute.className}" '
                  '(${parentRoute.path}) is not a shell. Add isShell: true '
                  'to the parent @Route annotation.',
              filePath: route.filePath,
              line: route.line,
            ),
          );
        }
      }
    }

    // ── Redirect targets ──
    final routePaths = routes.map((r) => r.path).toSet();
    for (final redirect in redirects) {
      if (!routePaths.contains(redirect.to) && redirect.to != '/') {
        errors.add(
          RouteValidationError(
            code: RouteValidationErrorCode.danglingRedirectTarget,
            message:
                'Redirect rule from "${redirect.from}" targets undefined '
                'route "${redirect.to}". Declare a @Route with that path or '
                'fix the redirect target.',
            filePath: redirect.filePath,
            line: redirect.line,
          ),
        );
      }
    }

    return errors;
  }

  static String _stripSlashes(String value) =>
      value.replaceAll(RegExp(r'^/+|/+$'), '');
}
