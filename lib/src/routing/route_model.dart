/// Data model for the @Route annotation pipeline (spec 033).
library;

/// A single scanned `@Route` annotation on a View class.
class RouteDeclaration {
  const RouteDeclaration({
    required this.viewClassName,
    required this.path,
    required this.name,
    required this.importUri,
    required this.filePath,
    required this.line,
    this.deepLinkAware = false,
    this.isShell = false,
    this.parent,
    this.middleware = const <String>[],
    this.params = const <String, String>{},
    this.query = const <String>[],
    this.guardRedirect,
    this.viewAcceptsChild = false,
  });

  /// The annotated View class name, e.g. `ProductsView`.
  final String viewClassName;

  /// Declared URL pattern, e.g. `/products/:id`.
  final String path;

  /// Route name (explicit or derived from the View class name).
  final String name;

  /// Import URI relative to the target package's `lib/`,
  /// e.g. `src/features/products/products_view.dart`.
  final String importUri;

  /// Absolute source file path (error reporting).
  final String filePath;

  /// 1-based annotation line (error reporting).
  final int line;

  final bool deepLinkAware;
  final bool isShell;

  /// Parent route NAME this route nests under (null when top-level).
  final String? parent;

  /// Guard class names from `middleware` / `@Route.middleware`.
  final List<String> middleware;

  /// Path parameter name → declared type name (`'int'`, `'String'`,
  /// `'double'`, `'bool'`).
  final Map<String, String> params;

  /// Query parameter names.
  final List<String> query;

  /// Where to redirect when a guard denies (null → guard default).
  final String? guardRedirect;

  /// Whether the View constructor declares a `child` parameter (shells).
  final bool viewAcceptsChild;

  /// Path parameter names extracted from [path] (e.g. `id` from
  /// `/products/:id`), in declaration order.
  List<String> get pathParameterNames {
    return path
        .split('/')
        .where((segment) => segment.startsWith(':'))
        .map((segment) => segment.substring(1))
        .where((name) => name.isNotEmpty)
        .toList();
  }
}

/// A scanned redirect rule (`@Route.redirect` or `@Route(redirect: ...)`).
class RouteRedirectRule {
  const RouteRedirectRule({
    required this.from,
    required this.to,
    required this.filePath,
    required this.line,
  });

  final String from;
  final String to;

  /// Absolute source file path (error reporting).
  final String filePath;

  /// 1-based annotation line.
  final int line;
}

/// A non-fatal (or strict-mode fatal) scan finding, e.g. `@Route` on a
/// non-View class.
class RouteScanIssue {
  const RouteScanIssue({
    required this.message,
    required this.filePath,
    required this.line,
    required this.isError,
  });

  final String message;
  final String filePath;
  final int line;
  final bool isError;
}

/// Everything the scanner found in a `lib/` directory.
class RouteScanResult {
  const RouteScanResult({
    required this.routes,
    required this.redirects,
    required this.issues,
    required this.classIndex,
  });

  final List<RouteDeclaration> routes;
  final List<RouteRedirectRule> redirects;
  final List<RouteScanIssue> issues;

  /// Class name → import URI (relative to `lib/`) for every class in the
  /// scanned tree; used to resolve guard imports.
  final Map<String, String> classIndex;
}

/// One actionable validation error (FR-006).
class RouteCompilationError {
  const RouteCompilationError({
    required this.message,
    required this.filePath,
    required this.line,
  });

  final String message;
  final String filePath;
  final int line;

  @override
  String toString() => '$filePath:$line: $message';
}

/// Thrown by the compiler when validation fails; carries EVERY error (not
/// fail-fast) so one build reports all misconfigurations.
class RouteCompilationException implements Exception {
  RouteCompilationException(this.errors);

  final List<RouteCompilationError> errors;

  @override
  String toString() {
    final buffer = StringBuffer(
      'Route annotation compilation failed with '
      '${errors.length} error(s):',
    );
    for (final error in errors) {
      buffer.write('\n  - $error');
    }
    return buffer.toString();
  }
}

/// Outcome of a successful compile.
class RouteCompilationOutcome {
  const RouteCompilationOutcome({
    required this.routeCount,
    required this.redirectCount,
    required this.writtenFiles,
    required this.skipped,
  });

  /// Number of routes compiled.
  final int routeCount;

  /// Number of redirect rules compiled.
  final int redirectCount;

  /// Absolute path → content of every artifact written.
  final Map<String, String> writtenFiles;

  /// True when there was nothing to do (no annotations, no stale router).
  final bool skipped;
}
