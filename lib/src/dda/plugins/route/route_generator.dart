import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';

/// Generates `lib/src/routing/zfa_router.g.dart` from collected
/// `@ZfaRoute` annotation metadata.
///
/// Produces:
/// - A `GoRouter` factory function with all discovered routes
/// - Typed `RouteParams` class per route that has path or query parameters
/// - Redirect rules from `@ZfaRoute.redirect` annotations
/// - `ShellRoute` wrappers for nested route groups (parentPath)
/// - Guard-based `redirect` callbacks for middleware-protected routes
/// - Deep link path patterns documented in generated code
///
/// Usage in `zfa build` pipeline:
/// ```dart
/// final plugin = RouteDDAPlugin();
/// ZorphyPluginRegistry.register(plugin);
/// // ... build runs, plugin collects routes ...
/// if (plugin.hasRoutes) {
///   final code = plugin.generateRouterFile();
///   File('lib/src/routing/zfa_router.g.dart').writeAsStringSync(code);
/// }
/// ```
class RouteGenerator {
  RouteGenerator({this.packageName = 'zuraffa'});

  /// Package name used to build import URIs for generated code.
  final String packageName;

  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  final List<_RouteEntry> _routes = [];
  final List<_RedirectEntry> _redirects = [];

  /// Whether any routes or redirects were collected.
  bool get hasRoutes => _routes.isNotEmpty || _redirects.isNotEmpty;

  /// Register a route view discovered by the AST scanner.
  void addRoute({
    required String path,
    required String name,
    required String className,
    required String importUri,
    bool deepLinkAware = false,
    String? parentPath,
    Map<String, String> queryParameters = const {},
    List<String> middleware = const [],
    Map<String, String> middlewareImports = const {},
  }) {
    final pathParams = _extractPathParams(path);
    _routes.add(
      _RouteEntry(
        path: path,
        name: name,
        className: className,
        importUri: importUri,
        deepLinkAware: deepLinkAware,
        parentPath: parentPath,
        pathParams: pathParams,
        queryParameters: queryParameters,
        middleware: middleware,
        middlewareImports: middlewareImports,
      ),
    );
  }

  /// Register a redirect rule discovered by the AST scanner.
  void addRedirect({required String from, required String to}) {
    _redirects.add(_RedirectEntry(from: from, to: to));
  }

  /// Generate the complete `zfa_router.g.dart` file content.
  String generate() {
    final library = cb.Library((b) {
      b.generatedByComment = 'zfa DDA pipeline — Track 6.1';

      // ── Imports ──
      final viewImports = <String>{};
      for (final route in _routes) {
        if (route.importUri.isNotEmpty) {
          viewImports.add(route.importUri);
        }
        // Add middleware imports
        for (final uri in route.middlewareImports.values) {
          if (uri.isNotEmpty) {
            viewImports.add(uri);
          }
        }
      }
      b.directives.add(cb.Directive.import('package:go_router/go_router.dart'));
      b.directives.add(cb.Directive.import('package:flutter/material.dart'));
      b.directives.add(cb.Directive.import('package:zuraffa/zuraffa.dart'));
      for (final uri in viewImports) {
        b.directives.add(cb.Directive.import(uri));
      }

      // ── RouteParams classes ──
      for (final route in _routes) {
        if (route.hasParams) {
          b.body.add(_routeParamsClass(route));
        }
      }

      // ── ZuraffaRouteState adapter (only needed when guards exist) ──
      final hasMiddleware = _routes.any((route) => route.middleware.isNotEmpty);
      if (hasMiddleware) {
        b.body.add(
          cb.Method(
            (m) => m
              ..name = '_zuraffaRouteState'
              ..returns = cb.refer('ZuraffaRouteState')
              ..requiredParameters.add(
                cb.Parameter(
                  (p) => p
                    ..name = 'state'
                    ..type = cb.refer('GoRouterState'),
                ),
              )
              ..body = cb.Code(
                'return ZuraffaRouteState('
                "location: state.uri.toString(), "
                'path: state.fullPath ?? state.matchedLocation, '
                'matchedLocation: state.matchedLocation, '
                'queryParameters: state.uriQueryParameters, '
                'pathParameters: state.pathParameters, '
                'extra: state.extra, '
                ');',
              ),
          ),
        );
      }

      // ── createZfaRouter() function ──
      b.body.add(_routerFunction());
    });

    final emitter = cb.DartEmitter();
    final raw = library.accept(emitter).toString();
    return _formatter.format(raw);
  }

  // ────────────────────────────────────────────────────────────────
  // RouteParams class
  // ────────────────────────────────────────────────────────────────

  cb.Class _routeParamsClass(_RouteEntry route) {
    final className = '${route.className}RouteParams';
    final fields = <cb.Field>[];
    final constructorParams = <cb.Parameter>[];
    final factoryAssignments = <String>[];

    // Path params
    for (final p in route.pathParams) {
      fields.add(
        cb.Field(
          (f) => f
            ..name = p.name
            ..type = cb.refer(p.dartType)
            ..modifier = cb.FieldModifier.final$,
        ),
      );
      constructorParams.add(
        cb.Parameter(
          (p2) => p2
            ..name = p.name
            ..toThis = true
            ..required = true,
        ),
      );
      final parser = _paramParser(p.name, p.dartType, isPath: true);
      factoryAssignments.add(parser);
    }

    // Query params
    for (final entry in route.queryParameters.entries) {
      fields.add(
        cb.Field(
          (f) => f
            ..name = entry.key
            ..type = cb.refer(entry.value)
            ..modifier = cb.FieldModifier.final$,
        ),
      );
      constructorParams.add(
        cb.Parameter(
          (p) => p
            ..name = entry.key
            ..toThis = true
            ..required = true,
        ),
      );
      final parser = _paramParser(entry.key, entry.value, isPath: false);
      factoryAssignments.add(parser);
    }

    // pathParameters and queryParameters maps
    fields.add(
      cb.Field(
        (f) => f
          ..name = 'pathParameters'
          ..type = cb.refer('Map<String, String>')
          ..modifier = cb.FieldModifier.final$,
      ),
    );
    constructorParams.add(
      cb.Parameter(
        (p) => p
          ..name = 'pathParameters'
          ..toThis = true
          ..required = true,
      ),
    );
    fields.add(
      cb.Field(
        (f) => f
          ..name = 'queryParameters'
          ..type = cb.refer('Map<String, String>')
          ..modifier = cb.FieldModifier.final$,
      ),
    );
    constructorParams.add(
      cb.Parameter(
        (p) => p
          ..name = 'queryParameters'
          ..toThis = true
          ..required = true,
      ),
    );

    factoryAssignments.add('pathParameters: state.pathParameters');
    factoryAssignments.add('queryParameters: state.uriQueryParameters');

    // Build factory body
    final factoryBody = 'return $className(${factoryAssignments.join(', ')});';

    return cb.Class(
      (c) => c
        ..name = className
        ..extend = cb.refer('RouteParams')
        ..fields.addAll(fields)
        ..constructors.addAll([
          // Private generative constructor
          cb.Constructor(
            (ctor) => ctor
              ..name = '_'
              ..optionalParameters.addAll(constructorParams),
          ),
          // Factory constructor
          cb.Constructor(
            (ctor) => ctor
              ..factory = true
              ..name = 'fromGoRouterState'
              ..requiredParameters.add(
                cb.Parameter(
                  (p) => p
                    ..name = 'state'
                    ..type = cb.refer('GoRouterState'),
                ),
              )
              ..body = cb.Code(factoryBody),
          ),
        ]),
    );
  }

  String _paramParser(String name, String type, {required bool isPath}) {
    final source = isPath
        ? "state.pathParameters['$name']"
        : "state.uriQueryParameters['$name']";
    switch (type) {
      case 'int':
        return isPath
            ? "$name: int.parse($source!)"
            : "$name: int.tryParse($source ?? '') ?? 0";
      case 'double':
        return isPath
            ? "$name: double.parse($source!)"
            : "$name: double.tryParse($source ?? '') ?? 0.0";
      case 'bool':
        return "$name: $source == 'true'";
      default:
        return isPath ? "$name: $source!" : "$name: $source ?? ''";
    }
  }

  // ────────────────────────────────────────────────────────────────
  // GoRouter factory function
  // ────────────────────────────────────────────────────────────────

  cb.Method _routerFunction() {
    // Build route tree: group by parentPath
    final standaloneRoutes = <_RouteEntry>[];
    final shellGroups = <String, List<_RouteEntry>>{};
    for (final route in _routes) {
      if (route.parentPath != null) {
        shellGroups.putIfAbsent(route.parentPath!, () => []);
        shellGroups[route.parentPath!]!.add(route);
      } else {
        standaloneRoutes.add(route);
      }
    }

    // Build the GoRoute expressions
    final routeLines = <String>[];

    // Shell routes first
    for (final entry in shellGroups.entries) {
      final childLines = <String>[];
      for (final child in entry.value) {
        childLines.add(_goRouteCode(child, indent: 6));
      }
      routeLines.add(
        '    ShellRoute('
        'builder: (context, state, child) => child, '
        'routes: [',
      );
      routeLines.addAll(childLines);
      routeLines.add('    ]),');
    }

    // Standalone routes
    for (final route in standaloneRoutes) {
      routeLines.add(_goRouteCode(route, indent: 4));
    }

    // Build complete GoRouter expression
    final goRouterParts = <String>[];
    goRouterParts.add('return GoRouter(');
    goRouterParts.add('  routes: [');
    goRouterParts.addAll(routeLines);
    goRouterParts.add('  ],');

    // Add redirect callback if there are redirects
    if (_redirects.isNotEmpty) {
      final redirectParts = <String>[];
      for (final r in _redirects) {
        redirectParts.add(
          "    if (state.matchedLocation == '${r.from}') return '${r.to}';",
        );
      }
      goRouterParts.add(
        '  // Auto-redirect rules from @ZfaRoute.redirect annotations',
      );
      goRouterParts.add('  redirect: (context, state) {');
      goRouterParts.addAll(redirectParts);
      goRouterParts.add('    return null;');
      goRouterParts.add('  },');
    }

    goRouterParts.add('  initialLocation: \'/\',');
    goRouterParts.add(');');

    return cb.Method(
      (m) => m
        ..name = 'createZfaRouter'
        ..returns = cb.refer('GoRouter')
        ..body = cb.Code(goRouterParts.join('\n')),
    );
  }

  String _goRouteCode(_RouteEntry route, {required int indent}) {
    final pad = ' ' * indent;
    final lines = <String>[];

    // Deep link comment
    if (route.deepLinkAware) {
      lines.add('$pad// Deep-link-aware: register in iOS/Android config');
    }

    // GoRoute start
    lines.add('${pad}GoRoute(');
    lines.add('$pad  path: ${_dartLiteral(route.path)},');
    lines.add('$pad  name: ${_dartLiteral(route.name)},');

    // Builder
    final hasParams = route.hasParams;
    if (hasParams) {
      lines.add('$pad  builder: (context, state) {');
      lines.add(
        '$pad    final params = ${route.className}RouteParams.fromGoRouterState(state);',
      );
      lines.add('$pad    return ${route.className}(params);');
      lines.add('$pad  },');
    } else {
      lines.add(
        '$pad  builder: (context, state) => const ${route.className}(),',
      );
    }

    // Middleware redirect
    if (route.middleware.isNotEmpty) {
      final checks = <String>[];
      for (var i = 0; i < route.middleware.length; i++) {
        final guard = route.middleware[i];
        checks.add(
          'final _g$i = $guard();'
          'if (!await _g$i.canActivate(_zuraffaRouteState(state))) '
          'return _g$i.onRejected(_zuraffaRouteState(state));',
        );
      }
      lines.add('$pad  redirect: (context, state) async {');
      lines.add('$pad    ${checks.join(' ')}');
      lines.add('$pad    return null;');
      lines.add('$pad  },');
    }

    lines.add('$pad),');
    return lines.join('\n');
  }

  String _dartLiteral(String value) => "'$value'";

  // ────────────────────────────────────────────────────────────────
  // Path parameter extraction
  // ────────────────────────────────────────────────────────────────

  static List<_PathParam> _extractPathParams(String path) {
    final params = <_PathParam>[];
    final regex = RegExp(r':([a-zA-Z_][a-zA-Z0-9_]*)');
    for (final match in regex.allMatches(path)) {
      params.add(_PathParam(name: match.group(1)!, dartType: 'String'));
    }
    return params;
  }
}

// ── Internal data models ──

class _RouteEntry {
  _RouteEntry({
    required this.path,
    required this.name,
    required this.className,
    required this.importUri,
    required this.deepLinkAware,
    this.parentPath,
    this.pathParams = const [],
    this.queryParameters = const {},
    this.middleware = const [],
    this.middlewareImports = const {},
  });

  final String path;
  final String name;
  final String className;
  final String importUri;
  final bool deepLinkAware;
  final String? parentPath;
  final List<_PathParam> pathParams;
  final Map<String, String> queryParameters;
  final List<String> middleware;
  final Map<String, String> middlewareImports;

  bool get hasParams => pathParams.isNotEmpty || queryParameters.isNotEmpty;
}

class _RedirectEntry {
  _RedirectEntry({required this.from, required this.to});
  final String from;
  final String to;
}

class _PathParam {
  _PathParam({required this.name, required this.dartType});
  final String name;
  final String dartType;
}
