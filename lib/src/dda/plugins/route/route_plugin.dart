import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;
import '../../compiler/zorphy_decorator_plugin.dart';
import '../../models/decorator_ast.dart';
import '../../models/zorphy_context.dart';
import 'route_generator.dart';
import 'route_validator.dart';

/// DDA plugin that processes `@ZfaRoute` (and `@Route`) annotations and
/// collects route metadata for GoRouter configuration generation.
///
/// This plugin is registered automatically when `zfa build` runs the DDA
/// route stage (`RouteBuildStage`). After the build, call
/// [generateRouterFile] to emit `lib/src/routing/zfa_router.g.dart`.
///
/// Supported annotations:
/// - `@ZfaRoute(path: '/products/:id', deepLinkAware: true)` — view route
/// - `@Route(path: '/home')` — alias spelling
/// - `@ZfaRoute.redirect(from: '/old', to: '/new')` — redirect rule
/// - `@Route.redirect(from: '/old', to: '/new')` — alias spelling
/// - Legacy `@ZfaRoute(redirectFrom: '/old', redirectTo: '/new')`
///
/// Features:
/// - Path parameter extraction (`:id` → typed field via `pathParameters`)
/// - Deep link registration markers (iOS universal links / Android app links)
/// - Nested routes via `parent` (name or path) / legacy `parentPath`
/// - Shell routes via `isShell`
/// - Route guards via `middleware`
/// - Query parameter type declarations
/// - Generated `RouteParams` class per route with typed fields
/// - Non-View annotation targets are REJECTED and surfaced by the
///   [RouteValidator] as build errors (FR-006) instead of being dropped.
class RouteDDAPlugin extends ZorphyDecoratorPlugin {
  RouteDDAPlugin({this.packageName = 'zuraffa'});

  /// The package name used to build import URIs. Defaults to `zuraffa`.
  final String packageName;

  late var _generator = RouteGenerator();
  final List<NonViewTargetInfo> _nonViewTargets = <NonViewTargetInfo>[];

  @override
  String get targetDecorator => 'Route';

  /// Both spellings: the canonical `ZfaRoute` and the `Route` typedef alias.
  @override
  List<String> get targetDecorators => const ['Route', 'ZfaRoute'];

  @override
  int get priority => 10;

  @override
  void onBuildStart(Map<String, dynamic> config) {
    final projectRoot = config['projectRoot'] as String?;
    if (projectRoot != null) {
      final pubspecPath = p.join(projectRoot, 'pubspec.yaml');
      try {
        final pubspecFile = File(pubspecPath);
        if (pubspecFile.existsSync()) {
          final pubspecContent = pubspecFile.readAsStringSync();
          final pubspec = loadYaml(pubspecContent) as Map;
          final name = pubspec['name'] as String?;
          if (name != null && name.isNotEmpty) {
            _generator = RouteGenerator(packageName: name);
          }
        }
      } catch (e) {
        // Silently ignore errors reading pubspec
      }
    }
  }

  @override
  void onApply(
    MethodAST method,
    DecoratorAST decorator,
    ZorphyContext context,
  ) {
    if (method.elementKind != 'class') {
      _reject(
        '${method.className ?? ''}.${method.name}',
        '@Route must annotate a View class, but it was found on the '
            '${method.elementKind} "${method.name}". Move the annotation to '
            'a View class.',
        decorator,
      );
      return;
    }

    final className = method.name;
    final importUri = _extractImportUri(method.libraryUri);
    final location = decorator.sourceLocation;

    // ── Redirect rules ──
    // @Route.redirect(from: ..., to: ...) / @ZfaRoute.redirect(...)
    if (decorator.constructorName == 'redirect') {
      final from = _stringArg(decorator, 'from');
      final to = _stringArg(decorator, 'to');
      if (from == null || to == null) {
        _reject(
          className,
          'Redirect annotation requires both "from" and "to" path arguments '
          '(e.g. @Route.redirect(from: \'/old\', to: \'/new\')).',
          decorator,
        );
        return;
      }
      _generator.addRedirect(
        from: from,
        to: to,
        filePath: location?.filePath,
        line: location?.line,
      );
      return;
    }

    // Legacy redirect named args: redirectFrom / redirectTo
    final redirectFrom = _stringArg(decorator, 'redirectFrom');
    final redirectTo = _stringArg(decorator, 'redirectTo');
    final path = _stringArg(decorator, 'path');
    if (redirectFrom != null &&
        redirectTo != null &&
        (path == null || path.isEmpty)) {
      _generator.addRedirect(
        from: redirectFrom,
        to: redirectTo,
        filePath: location?.filePath,
        line: location?.line,
      );
      return;
    }

    // ── Route shape validation ──
    if (path == null || path.isEmpty) {
      _reject(
        className,
        'Missing required "path" argument '
        '(e.g. @ZfaRoute(path: \'/products\')).',
        decorator,
      );
      return;
    }

    if (!_isViewLike(className)) {
      _reject(
        className,
        'class name does not end in View/Shell/Page/Screen. '
        '@Route may only annotate View classes.',
        decorator,
      );
      return;
    }

    // ── Standard route ──
    final name = _stringArg(decorator, 'name') ?? _routeNameFrom(className);
    final deepLinkAware = _boolArg(decorator, 'deepLinkAware');
    final isShell = _boolArg(decorator, 'isShell');
    final parent =
        _stringArg(decorator, 'parent') ?? _stringArg(decorator, 'parentPath');
    final queryParams = _parseMapLiteral(
      decorator.namedArgs['queryParameters'],
    );
    final pathParams = _parseMapLiteral(decorator.namedArgs['pathParameters']);
    final middleware = _parseMiddleware(decorator);
    final middlewareImports = _extractMiddlewareImports(
      middleware,
      method.libraryUri,
    );

    _generator.addRoute(
      path: path,
      name: name,
      className: className,
      importUri: importUri,
      deepLinkAware: deepLinkAware,
      isShell: isShell,
      parent: parent,
      queryParameters: queryParams,
      pathParameters: pathParams,
      middleware: middleware,
      middlewareImports: middlewareImports,
      filePath: location?.filePath,
      line: location?.line,
    );
  }

  /// Generate the router configuration file content. With no collected
  /// routes this emits a valid EMPTY configuration.
  String generateRouterFile() => _generator.generate();

  /// Whether any routes or redirects were collected.
  bool get hasRoutes => _generator.hasRoutes;

  /// Snapshot of collected routes (validator input).
  List<RouteEntryInfo> get routeInfos => _generator.routeInfos;

  /// Snapshot of collected redirect rules (validator input).
  List<RedirectRuleInfo> get redirectInfos => _generator.redirectInfos;

  /// Annotations that were rejected as route targets (validator input).
  List<NonViewTargetInfo> get nonViewTargets =>
      List.unmodifiable(_nonViewTargets);

  // ── Helpers ──

  void _reject(String className, String reason, DecoratorAST decorator) {
    final location = decorator.sourceLocation;
    _nonViewTargets.add(
      NonViewTargetInfo(
        className: className,
        reason: reason,
        filePath: location?.filePath,
        line: location?.line,
      ),
    );
  }

  static bool _isViewLike(String className) =>
      className.endsWith('View') ||
      className.endsWith('Shell') ||
      className.endsWith('Page') ||
      className.endsWith('Screen');

  /// Lenient string arg: accepts the typed value from the scanner's literal
  /// parsing (and tolerates a legacy raw-source string).
  String? _stringArg(DecoratorAST decorator, String key) {
    final value = decorator.namedArgs[key];
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Lenient bool arg: typed `bool` or the legacy raw source `'true'`.
  bool _boolArg(DecoratorAST decorator, String key) {
    final value = decorator.namedArgs[key];
    if (value is bool) return value;
    if (value is String) return value.trim() == 'true';
    return false;
  }

  String _extractImportUri(String? libraryUri) {
    if (libraryUri == null) return '';
    if (libraryUri.contains('/lib/')) {
      final parts = libraryUri.split('/lib/');
      if (parts.length == 2) {
        // Use the GENERATOR's package name: onBuildStart refreshes it from
        // the target project's pubspec.yaml (the plugin field stays at its
        // constructor default).
        return 'package:${_generator.packageName}/${parts[1]}';
      }
    }
    return libraryUri;
  }

  String _routeNameFrom(String className) {
    // ProductDetailView → productDetail
    if (className.endsWith('View')) {
      final base = className.substring(0, className.length - 4);
      // PascalCase to camelCase
      return base.substring(0, 1).toLowerCase() + base.substring(1);
    }
    // PascalCase to camelCase
    return className.substring(0, 1).toLowerCase() + className.substring(1);
  }

  /// Parses a map-literal raw source like `{'q': 'String', 'page': 'int'}`
  /// into `{q: String, page: int}`. Returns an empty map for null/other
  /// shapes.
  Map<String, String> _parseMapLiteral(Object? raw) {
    if (raw == null) return const {};
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    if (raw is String) {
      final result = <String, String>{};
      final entryRegex = RegExp(
        r'''['"]?([a-zA-Z_][a-zA-Z0-9_]*)['"]?\s*:\s*['"]?([a-zA-Z_][a-zA-Z0-9_]*)['"]?''',
      );
      for (final match in entryRegex.allMatches(raw)) {
        result[match.group(1)!] = match.group(2)!;
      }
      return result;
    }
    return const {};
  }

  List<String> _parseMiddleware(DecoratorAST decorator) {
    final raw = decorator.namedArgs['middleware'];
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String) {
      // Legacy raw source: strip brackets, split on commas.
      final inner = raw.replaceAll('[', '').replaceAll(']', '').trim();
      if (inner.isEmpty) return const [];
      return inner
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Map<String, String> _extractMiddlewareImports(
    List<String> middleware,
    String? libraryUri,
  ) {
    if (middleware.isEmpty || libraryUri == null) return const {};

    final imports = <String, String>{};
    final baseImport = _extractImportUri(libraryUri);

    // For each middleware class, assume it's in the same library
    // or needs the same import as the route view
    for (final guard in middleware) {
      imports[guard] = baseImport;
    }

    return imports;
  }
}
