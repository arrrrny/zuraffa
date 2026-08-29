import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';

import 'route_validator.dart';

/// Generates `lib/src/routing/zfa_router.g.dart` from collected
/// `@ZfaRoute` annotation metadata.
///
/// Produces:
/// - A `GoRouter` factory function with all discovered routes
/// - Typed `RouteParams` class per route that has path or query parameters
/// - Redirect rules from `@ZfaRoute.redirect` annotations
/// - `ShellRoute` wrappers for nested route groups: `isShell` routes render
///   their View around the children; legacy `parentPath` groups render a
///   pass-through shell
/// - Guard-based `redirect` callbacks for middleware-protected routes
/// - Deep link path patterns documented in generated code
///
/// With no routes collected, `generate()` emits a valid EMPTY configuration
/// (`createZfaRouter()` over an empty route list) — used when a previously
/// generated file must be regenerated after all routes were removed.
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

  /// Public snapshot of the collected routes (for validation + reporting).
  List<RouteEntryInfo> get routeInfos => List.unmodifiable(
    _routes.map(
      (r) => RouteEntryInfo(
        path: r.path,
        name: r.name,
        className: r.className,
        importUri: r.importUri,
        deepLinkAware: r.deepLinkAware,
        isShell: r.isShell,
        parent: r.parent,
        queryParameters: r.queryParameters,
        pathParameters: r.pathParameters,
        middleware: r.middleware,
        filePath: r.filePath,
        line: r.line,
      ),
    ),
  );

  /// Cached public snapshot used for parent resolution (the validator's
  /// resolveParentPath operates on [RouteEntryInfo]).
  List<RouteEntryInfo> get _infoList => routeInfos;

  /// Public snapshot of the collected redirect rules.
  List<RedirectRuleInfo> get redirectInfos => List.unmodifiable(
    _redirects.map(
      (r) => RedirectRuleInfo(
        from: r.from,
        to: r.to,
        filePath: r.filePath,
        line: r.line,
      ),
    ),
  );

  /// Register a route view discovered by the AST scanner.
  void addRoute({
    required String path,
    required String name,
    required String className,
    required String importUri,
    bool deepLinkAware = false,
    bool isShell = false,
    String? parent,
    String? parentPath,
    Map<String, String> queryParameters = const {},
    Map<String, String> pathParameters = const {},
    List<String> middleware = const [],
    Map<String, String> middlewareImports = const {},
    String? filePath,
    int? line,
  }) {
    // Normalize: `parent` (name-or-path) wins; legacy `parentPath` is a path
    // reference. Keep the raw reference for validation; resolution happens
    // at generate() time when every route is known.
    final parentRef = parent ?? parentPath;
    _routes.add(
      _RouteEntry(
        path: path,
        name: name,
        className: className,
        importUri: importUri,
        deepLinkAware: deepLinkAware,
        isShell: isShell,
        parent: parentRef,
        queryParameters: queryParameters,
        pathParameters: pathParameters,
        middleware: middleware,
        middlewareImports: middlewareImports,
        filePath: filePath,
        line: line,
      ),
    );
  }

  /// Register a redirect rule discovered by the AST scanner.
  void addRedirect({
    required String from,
    required String to,
    String? filePath,
    int? line,
  }) {
    _redirects.add(
      _RedirectEntry(from: from, to: to, filePath: filePath, line: line),
    );
  }

  /// Generate the complete `zfa_router.g.dart` file content.
  String generate() {
    final library = cb.Library((b) {
      b.generatedByComment = 'zfa DDA pipeline — Track 6.1. DO NOT EDIT.';

      // ── Imports (sorted for deterministic, idempotent output) ──
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
      for (final uri in viewImports.toList()..sort()) {
        b.directives.add(cb.Directive.import(uri));
      }

      // ── RouteParams classes ──
      for (final route in _effectiveRoutes()) {
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
  // Parent resolution + effective paths
  // ────────────────────────────────────────────────────────────────

  /// Routes annotated as shells that actually own children.
  List<_RouteEntry> _shells() {
    return _routes
        .where((r) => r.isShell && _childrenOf(r).isNotEmpty)
        .toList();
  }

  /// Routes whose `parent` resolves to [shell]'s path (excluding the shell
  /// itself).
  List<_RouteEntry> _childrenOf(_RouteEntry shell) {
    return _routes.where((r) {
      if (r == shell || r.parent == null) return false;
      return RouteValidator.resolveParentPath(r.parent!, _infoList) ==
          shell.path;
    }).toList();
  }

  /// The routes that carry generated RouteParams classes: every route
  /// (children carry their EFFECTIVE — absolute — paths so `:param`
  /// extraction works on relative child paths too).
  List<_RouteEntry> _effectiveRoutes() {
    return _routes.map((r) => _effectiveRouteFor(r)).toList();
  }

  static bool _pathHasPrefix(String path, String prefix) =>
      path == prefix || path.startsWith('$prefix/');

  static String _joinPath(String parent, String child) {
    final c = child.startsWith('/') ? child : '/$child';
    return parent.endsWith('/') ? '$parent${c.substring(1)}' : '$parent$c';
  }

  // ────────────────────────────────────────────────────────────────
  // RouteParams class
  // ────────────────────────────────────────────────────────────────

  cb.Class _routeParamsClass(_RouteEntry route) {
    final className = '${route.className}RouteParams';
    final fields = <cb.Field>[];
    final constructorParams = <cb.Parameter>[];
    final factoryAssignments = <String>[];

    // Path params (typed via pathParameters; String by default)
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
            ..named = true
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
            ..named = true
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
          ..named = true
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
          ..named = true
          ..toThis = true
          ..required = true,
      ),
    );

    factoryAssignments.add('pathParameters: state.pathParameters');
    factoryAssignments.add('queryParameters: state.uriQueryParameters');

    // Build factory body - call private named constructor
    final factoryBody =
        'return $className._(${factoryAssignments.join(', ')});';

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
    final routeLines = <String>[];

    // ── isShell shells: render the shell View around its children ──
    final emittedAsShellChildren = <_RouteEntry>{};
    for (final shell in _shells()) {
      final childLines = <String>[];
      for (final child in _childrenOf(shell)) {
        final effective = _effectiveRouteFor(child);
        emittedAsShellChildren.add(child);
        childLines.add(_goRouteCode(effective, indent: 6));
      }
      routeLines.add('    ShellRoute(');
      routeLines.add(
        '      builder: (context, state, child) => ${shell.className}(child: child),',
      );
      routeLines.add('      routes: [');
      routeLines.addAll(childLines);
      routeLines.add('      ],');
      routeLines.add('    ),');
    }

    // ── Legacy parentPath groups (no isShell owner): pass-through shell ──
    final legacyGroups = <String, List<_RouteEntry>>{};
    for (final route in _routes) {
      if (route.parent == null || emittedAsShellChildren.contains(route)) {
        continue;
      }
      final parentPath = RouteValidator.resolveParentPath(
        route.parent!,
        _infoList,
      );
      if (parentPath == null) continue;
      // Only group under a NON-shell parent here — shell parents were
      // handled above (or the parent owns no children).
      final parentRoute = _routes.firstWhere(
        (r) => r.path == parentPath,
        orElse: () => route,
      );
      if (parentRoute.isShell) continue;
      legacyGroups.putIfAbsent(parentPath, () => []).add(route);
    }
    for (final entry in legacyGroups.entries) {
      final childLines = <String>[];
      for (final child in entry.value) {
        emittedAsShellChildren.add(child);
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

    // ── Standalone routes (no parent, or shells without children) ──
    final shellsWithChildren = _shells().map((s) => s.path).toSet();
    for (final route in _routes) {
      // Shell that owns children: already emitted as a ShellRoute above.
      if (route.isShell && shellsWithChildren.contains(route.path)) continue;
      // Children emitted inside a shell above (isShell or legacy groups).
      if (emittedAsShellChildren.contains(route)) continue;
      routeLines.add(_goRouteCode(_effectiveRouteFor(route), indent: 4));
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

  /// The effective-route view of [route] (absolute path when nested under a
  /// shell).
  _RouteEntry _effectiveRouteFor(_RouteEntry route) {
    if (route.parent == null) return route;
    final parentPath = RouteValidator.resolveParentPath(
      route.parent!,
      _infoList,
    );
    if (parentPath != null && !_pathHasPrefix(route.path, parentPath)) {
      return route._withPath(_joinPath(parentPath, route.path));
    }
    return route;
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

  static List<_PathParam> _extractPathParams(
    String path,
    Map<String, String> declaredTypes,
  ) {
    final params = <_PathParam>[];
    final regex = RegExp(r':([a-zA-Z_][a-zA-Z0-9_]*)');
    for (final match in regex.allMatches(path)) {
      final name = match.group(1)!;
      params.add(
        _PathParam(name: name, dartType: declaredTypes[name] ?? 'String'),
      );
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
    required this.isShell,
    this.parent,
    this.queryParameters = const {},
    this.pathParameters = const {},
    this.middleware = const [],
    this.middlewareImports = const {},
    this.filePath,
    this.line,
  });

  final String path;
  final String name;
  final String className;
  final String importUri;
  final bool deepLinkAware;
  final bool isShell;
  final String? parent;
  final Map<String, String> queryParameters;
  final Map<String, String> pathParameters;
  final List<String> middleware;
  final Map<String, String> middlewareImports;
  final String? filePath;
  final int? line;

  bool get hasParams => pathParams.isNotEmpty || queryParameters.isNotEmpty;

  List<_PathParam> get pathParams =>
      RouteGenerator._extractPathParams(path, pathParameters);

  _RouteEntry _withPath(String effectivePath) => _RouteEntry(
    path: effectivePath,
    name: name,
    className: className,
    importUri: importUri,
    deepLinkAware: deepLinkAware,
    isShell: isShell,
    parent: parent,
    queryParameters: queryParameters,
    pathParameters: pathParameters,
    middleware: middleware,
    middlewareImports: middlewareImports,
    filePath: filePath,
    line: line,
  );
}

class _RedirectEntry {
  _RedirectEntry({
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

class _PathParam {
  _PathParam({required this.name, required this.dartType});
  final String name;
  final String dartType;
}
