import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;
import '../../compiler/zorphy_decorator_plugin.dart';
import '../../models/decorator_ast.dart';
import '../../models/zorphy_context.dart';
import 'route_generator.dart';

/// DDA plugin that processes `@ZfaRoute` annotations and collects
/// route metadata for GoRouter configuration generation.
///
/// This plugin is registered automatically when `zfa build` runs.
/// After the build, call [generateRouterFile] to emit
/// `lib/src/routing/zfa_router.g.dart`.
///
/// Supported annotations:
/// - `@ZfaRoute(path: '/products/:id', deepLinkAware: true)` — view route
/// - `@ZfaRoute.redirect(from: '/old', to: '/new')` — redirect rule
///
/// Features:
/// - Path parameter extraction (`:id` → typed field)
/// - Deep link registration (iOS universal links, Android app links)
/// - Nested routes via `parentPath`
/// - Route guards via `middleware`
/// - Query parameter type declarations
/// - Generated `RouteParams` class per route with typed fields
class RouteDDAPlugin extends ZorphyDecoratorPlugin {
  RouteDDAPlugin({this.packageName = 'zuraffa'});

  /// The package name used to build import URIs. Defaults to `zuraffa`.
  final String packageName;

  late var _generator = RouteGenerator();

  @override
  String get targetDecorator => 'Route';

  @override
  List<String> get targetDecorators => const ['Route'];

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
    if (method.elementKind != 'class') return;

    final className = method.name;
    final importUri = _extractImportUri(method.libraryUri);

    // Detect redirect pattern: @ZfaRoute.redirect(from: '...', to: '...')
    final redirectFrom = decorator.get<String>('redirectFrom');
    final redirectTo = decorator.get<String>('redirectTo');
    final path = decorator.get<String>('path');

    // Redirect-only route: no path, both redirectFrom and redirectTo present
    if (redirectFrom != null &&
        redirectTo != null &&
        (path == null || path.isEmpty)) {
      _generator.addRedirect(from: redirectFrom, to: redirectTo);
      return;
    }

    // Standard route: @ZfaRoute(path: '/products/:id', ...)
    if (path == null || path.isEmpty) return;

    final name = decorator.get<String>('name') ?? _routeNameFrom(className);
    final deepLinkAware = decorator.get<bool>('deepLinkAware') ?? false;
    final parentPath = decorator.get<String>('parentPath');
    final queryParams = _parseQueryParams(decorator);
    final middleware = _parseMiddleware(decorator);
    final middlewareImports = _extractMiddlewareImports(
      decorator,
      method.libraryUri,
    );

    _generator.addRoute(
      path: path,
      name: name,
      className: className,
      importUri: importUri,
      deepLinkAware: deepLinkAware,
      parentPath: parentPath,
      queryParameters: queryParams,
      middleware: middleware,
      middlewareImports: middlewareImports,
    );
  }

  /// Generate the router configuration file content.
  String generateRouterFile() => _generator.generate();

  /// Whether any routes were collected.
  bool get hasRoutes => _generator.hasRoutes;

  // ── Helpers ──

  String _extractImportUri(String? libraryUri) {
    if (libraryUri == null) return '';
    if (libraryUri.contains('/lib/')) {
      final parts = libraryUri.split('/lib/');
      if (parts.length == 2) {
        return 'package:$packageName/${parts[1]}';
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

  Map<String, String> _parseQueryParams(DecoratorAST decorator) {
    final raw = decorator.namedArgs['queryParameters'];
    if (raw == null) return const {};
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return const {};
  }

  List<String> _parseMiddleware(DecoratorAST decorator) {
    final raw = decorator.namedArgs['middleware'];
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Map<String, String> _extractMiddlewareImports(
    DecoratorAST decorator,
    String? libraryUri,
  ) {
    final middleware = _parseMiddleware(decorator);
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
