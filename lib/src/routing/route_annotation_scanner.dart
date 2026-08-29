/// Parse-only scanner for `@Route` annotations (spec 033).
///
/// Walks every non-generated `.dart` file under a `lib/` directory with the
/// analyzer's parse-only `parseString` (no resolution — fast enough for the
/// SC-002 two-second/100-View budget) and decodes:
/// - `@Route(path:, name:, deepLinkAware:, isShell:, parent:, middleware:,
///   params:, query:, guardRedirect:, redirect: RouteRedirect(...))`
/// - `@Route.redirect(from:, to:)` (named-constructor annotation)
/// - `@Route.middleware([GuardA, GuardB])` (merged with `@Route`)
///
/// Also indexes every class name → file for guard import resolution and
/// records non-View annotations as issues (error in strict mode, warning in
/// lenient mode).
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import 'route_model.dart';

class RouteAnnotationScanner {
  RouteAnnotationScanner({this.strictNonView = true});

  /// When true, `@Route` on a non-View class is an error; otherwise a
  /// warning and the route is still compiled.
  final bool strictNonView;

  Future<RouteScanResult> scanDirectory(String libDir) async {
    final routes = <RouteDeclaration>[];
    final redirects = <RouteRedirectRule>[];
    final issues = <RouteScanIssue>[];
    final classIndex = <String, String>{};

    final root = Directory(libDir);
    if (!root.existsSync()) {
      return RouteScanResult(
        routes: routes,
        redirects: redirects,
        issues: issues,
        classIndex: classIndex,
      );
    }

    final files =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.endsWith('.g.dart'))
            .where((f) => !f.path.endsWith('.freezed.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final content = file.readAsStringSync();

      // Fast path: skip parsing files with no @Route at all — keeps large
      // annotation-free projects (and the zuraffa repo itself) cheap.
      final hasRoute = content.contains('@Route');
      if (!hasRoute && !content.contains('@Route.')) {
        _indexClasses(content, file.path, libDir, classIndex);
        continue;
      }

      final result = parseString(
        content: content,
        path: file.path,
        throwIfDiagnostics: false,
      );

      _indexClasses(content, file.path, libDir, classIndex);

      final importUri = _relativeToLib(file.path, libDir);

      for (final declaration in result.unit.declarations) {
        if (declaration is! ClassDeclaration) continue;
        _scanClass(
          declaration,
          filePath: file.path,
          importUri: importUri,
          routes: routes,
          redirects: redirects,
          issues: issues,
        );
      }
    }

    return RouteScanResult(
      routes: routes,
      redirects: redirects,
      issues: issues,
      classIndex: classIndex,
    );
  }

  void _indexClasses(
    String content,
    String filePath,
    String libDir,
    Map<String, String> classIndex,
  ) {
    final classRegex = RegExp(r'class\s+([A-Za-z_][A-Za-z0-9_]*)');
    for (final match in classRegex.allMatches(content)) {
      final name = match.group(1)!;
      classIndex.putIfAbsent(name, () => _relativeToLib(filePath, libDir));
    }
  }

  void _scanClass(
    ClassDeclaration node, {
    required String filePath,
    required String importUri,
    required List<RouteDeclaration> routes,
    required List<RouteRedirectRule> redirects,
    required List<RouteScanIssue> issues,
  }) {
    final className = node.namePart.typeName.lexeme;
    final isView = _isViewClass(node);
    final viewAcceptsChild = _constructorAcceptsChild(node);

    final routeAnnotations = <Annotation>[];
    Annotation? standaloneRedirect;
    final standaloneMiddleware = <String>[];

    for (final annotation in node.metadata) {
      final name = annotation.name.name;
      if (name != 'Route' &&
          name != 'Route.redirect' &&
          name != 'Route.middleware' &&
          name != 'zfa.Route') {
        continue;
      }
      // Named-constructor annotations (@Route.redirect / @Route.middleware)
      // expose the prefix via annotation.name + constructorName.
      final constructor = annotation.constructorName?.token.lexeme;
      if (name == 'Route' || name == 'zfa.Route') {
        if (constructor == 'redirect') {
          standaloneRedirect = annotation;
          continue;
        }
        if (constructor == 'middleware') {
          standaloneMiddleware.addAll(
            _parseIdentifierList(_positionalSource(annotation) ?? ''),
          );
          continue;
        }
        routeAnnotations.add(annotation);
      } else if (name == 'Route.redirect') {
        standaloneRedirect = annotation;
      } else if (name == 'Route.middleware') {
        standaloneMiddleware.addAll(
          _parseIdentifierList(_positionalSource(annotation) ?? ''),
        );
      }
    }

    if (routeAnnotations.isEmpty &&
        standaloneRedirect == null &&
        standaloneMiddleware.isEmpty) {
      return;
    }

    if (routeAnnotations.isEmpty && standaloneRedirect != null) {
      // Standalone @Route.redirect — a pure redirect rule.
      final rule = _parseRedirectAnnotation(
        standaloneRedirect,
        filePath: filePath,
      );
      if (rule != null) redirects.add(rule);
      return;
    }

    if (routeAnnotations.isEmpty && standaloneMiddleware.isNotEmpty) {
      // @Route.middleware without a @Route(...) — nothing to attach to.
      issues.add(
        RouteScanIssue(
          message:
              '@Route.middleware on $className has no matching @Route '
              'annotation; the guards are ignored.',
          filePath: filePath,
          line: _lineOf(node.metadata.first),
          isError: true,
        ),
      );
      return;
    }

    if (!isView) {
      issues.add(
        RouteScanIssue(
          message:
              '@Route on non-View class $className — annotate a View '
              'class (name ends with "View" or extends a View).',
          filePath: filePath,
          line: routeAnnotations.isEmpty ? 1 : _lineOf(routeAnnotations.first),
          isError: strictNonView,
        ),
      );
    }

    // A @Route.redirect annotation combined with @Route(...) on the same
    // class contributes its redirect rule as well.
    if (standaloneRedirect != null) {
      final rule = _parseRedirectAnnotation(
        standaloneRedirect,
        filePath: filePath,
      );
      if (rule != null) redirects.add(rule);
    }

    for (final annotation in routeAnnotations) {
      final namedArgs = _namedArgSources(annotation);
      final path = _unquote(namedArgs['path']);
      if (path == null || path.isEmpty) {
        issues.add(
          RouteScanIssue(
            message:
                '@Route on $className is missing the required `path` '
                'argument.',
            filePath: filePath,
            line: _lineOf(annotation),
            isError: true,
          ),
        );
        continue;
      }

      final middleware = <String>[
        ..._parseIdentifierList(namedArgs['middleware'] ?? ''),
        ...standaloneMiddleware,
      ];

      // redirect: RouteRedirect(from: ..., to: ...)
      final redirectSource = namedArgs['redirect'];
      if (redirectSource != null) {
        final rule = _parseRouteRedirectSource(
          redirectSource,
          filePath: filePath,
          line: _lineOf(annotation),
        );
        if (rule != null) redirects.add(rule);
      }

      routes.add(
        RouteDeclaration(
          viewClassName: className,
          path: path,
          name: _unquote(namedArgs['name']) ?? _defaultRouteName(className),
          deepLinkAware: _parseBool(namedArgs['deepLinkAware']) ?? false,
          isShell: _parseBool(namedArgs['isShell']) ?? false,
          parent: _unquote(namedArgs['parent']),
          middleware: middleware,
          params: _parseTypeMap(namedArgs['params'] ?? ''),
          query: _parseStringListValues(namedArgs['query'] ?? ''),
          guardRedirect: _unquote(namedArgs['guardRedirect']),
          viewAcceptsChild: viewAcceptsChild,
          importUri: importUri,
          filePath: filePath,
          line: _lineOf(annotation),
        ),
      );
    }
  }

  // ------------------------------------------------------------------
  // Class shape helpers
  // ------------------------------------------------------------------

  bool _isViewClass(ClassDeclaration node) {
    if (node.namePart.typeName.lexeme.endsWith('View')) return true;
    final superclass = node.extendsClause?.superclass;
    if (superclass != null) {
      final name = superclass.toSource();
      if (name.endsWith('View')) return true;
      // Strip type arguments: `FooView<T>` → ends with View.
      final base = name.contains('<')
          ? name.substring(0, name.indexOf('<'))
          : name;
      if (base.endsWith('View')) return true;
    }
    return false;
  }

  bool _constructorAcceptsChild(ClassDeclaration node) {
    for (final member in node.body.members) {
      if (member is ConstructorDeclaration) {
        final params = member.parameters.parameters;
        for (final param in params) {
          if (param.name?.lexeme == 'child') return true;
        }
      }
    }
    return false;
  }

  String _defaultRouteName(String viewClassName) {
    var base = viewClassName;
    if (base.endsWith('View') && base.length > 'View'.length) {
      base = base.substring(0, base.length - 'View'.length);
    }
    if (base.isEmpty) return viewClassName.toLowerCase();
    return base[0].toLowerCase() + base.substring(1);
  }

  // ------------------------------------------------------------------
  // Annotation argument decoding (source-string level)
  // ------------------------------------------------------------------

  Map<String, String> _namedArgSources(Annotation annotation) {
    final args = <String, String>{};
    final argumentList = annotation.arguments;
    if (argumentList == null) return args;
    for (final argument in argumentList.arguments) {
      if (argument is NamedArgument) {
        args[argument.name.lexeme] = argument.argumentExpression.toSource();
      }
    }
    return args;
  }

  String? _positionalSource(Annotation annotation) {
    final argumentList = annotation.arguments;
    if (argumentList == null) return null;
    for (final argument in argumentList.arguments) {
      if (argument is! NamedArgument) return argument.toSource();
    }
    // Only named arguments present — no positional source.
    return null;
  }

  RouteRedirectRule? _parseRedirectAnnotation(
    Annotation annotation, {
    required String filePath,
  }) {
    final named = _namedArgSources(annotation);
    final from = _unquote(named['from']);
    final to = _unquote(named['to']);
    if (from == null || to == null) return null;
    return RouteRedirectRule(
      from: from,
      to: to,
      filePath: filePath,
      line: _lineOf(annotation),
    );
  }

  RouteRedirectRule? _parseRouteRedirectSource(
    String source, {
    required String filePath,
    required int line,
  }) {
    final from = _regexValue(source, 'from');
    final to = _regexValue(source, 'to');
    if (from == null || to == null) return null;
    return RouteRedirectRule(
      from: from,
      to: to,
      filePath: filePath,
      line: line,
    );
  }

  String? _regexValue(String source, String key) {
    final match = RegExp(
      "$key\\s*:\\s*('([^']*)'|\"([^\"]*)\")",
    ).firstMatch(source);
    if (match == null) return null;
    return match.group(2) ?? match.group(3);
  }

  List<String> _parseIdentifierList(String source) {
    if (source.trim().isEmpty) return const [];
    final inner = source.trim();
    if (!inner.startsWith('[')) {
      // A single bare identifier (e.g. positional arg without brackets).
      return [inner];
    }
    return inner
        .substring(1, inner.length - 1)
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  Map<String, String> _parseTypeMap(String source) {
    if (source.trim().isEmpty) return const {};
    final inner = source.trim();
    if (!inner.startsWith('{')) return const {};
    final body = inner.substring(1, inner.length - 1);
    final result = <String, String>{};
    for (final entry in body.split(',')) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) continue;
      final colon = trimmed.indexOf(':');
      if (colon < 0) continue;
      final key =
          _unquote(trimmed.substring(0, colon).trim()) ??
          trimmed.substring(0, colon).trim();
      final value = trimmed.substring(colon + 1).trim();
      if (value.isEmpty) continue;
      result[key] = value;
    }
    return result;
  }

  List<String> _parseStringListValues(String source) {
    if (source.trim().isEmpty) return const [];
    final inner = source.trim();
    if (!inner.startsWith('[')) return const [];
    return inner
        .substring(1, inner.length - 1)
        .split(',')
        .map((entry) => _unquote(entry.trim()) ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  static String? _unquote(String? source) {
    if (source == null) return null;
    final trimmed = source.trim();
    if (trimmed.length >= 2 &&
        ((trimmed.startsWith("'") && trimmed.endsWith("'")) ||
            (trimmed.startsWith('"') && trimmed.endsWith('"')))) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool? _parseBool(String? source) {
    if (source == null) return null;
    final trimmed = source.trim();
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;
    return null;
  }

  int _lineOf(Annotation annotation) {
    final root = annotation.root;
    if (root is CompilationUnit) {
      return root.lineInfo.getLocation(annotation.offset).lineNumber;
    }
    return 1;
  }

  String _relativeToLib(String filePath, String libDir) {
    final normalized = p.normalize(filePath);
    final normalizedLib = p.normalize(libDir);
    if (p.isWithin(normalizedLib, normalized)) {
      return p.relative(normalized, from: normalizedLib);
    }
    return p.basename(normalized);
  }
}
