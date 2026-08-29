/// Build-time validation for scanned @Route annotations (spec 033 FR-006,
/// SC-003, SC-004).
///
/// Validates (aggregating ALL errors, never fail-fast):
/// - duplicate route paths (lists both classes)
/// - missing parent route names
/// - parent reference cycles
/// - unsupported path parameter types (only String/int/double/bool)
/// - params keys that do not appear as `:name` segments in the path
/// - redirect targets that match no route path
/// - middleware guard classes that cannot be located
/// - controller type mismatches (SC-004) — when a sibling Controller class
///   declares a field/constructor param with the same name as a typed route
///   parameter but a different type
library;

import 'route_model.dart';

class RouteValidator {
  RouteValidator._();

  static const List<String> _supportedParamTypes = [
    'String',
    'int',
    'double',
    'bool',
  ];

  /// Validates [scan]; returns every error found (empty when valid).
  ///
  /// [strictNonView] escalates non-View scan issues to errors (default).
  /// [controllerSourceOf] resolves the source of the Controller associated
  /// with a View (used by the SC-004 type-mismatch check); return null to
  /// skip a view. When omitted, the check is skipped entirely.
  static List<RouteCompilationError> validate(
    RouteScanResult scan, {
    bool strictNonView = true,
    String? Function(RouteDeclaration view)? controllerSourceOf,
  }) {
    final errors = <RouteCompilationError>[];

    // Non-View issues (already classified by the scanner).
    if (strictNonView) {
      for (final issue in scan.issues.where((i) => i.isError)) {
        errors.add(
          RouteCompilationError(
            message: issue.message,
            filePath: issue.filePath,
            line: issue.line,
          ),
        );
      }
    }
    // Scanner-level errors other than non-View (e.g. missing path) are
    // always fatal.
    for (final issue in scan.issues.where(
      (i) => i.isError && !_isNonViewIssue(i),
    )) {
      errors.add(
        RouteCompilationError(
          message: issue.message,
          filePath: issue.filePath,
          line: issue.line,
        ),
      );
    }

    final routes = scan.routes;
    final routePaths = routes.map((r) => r.path).toSet();
    final names = routes.map((r) => r.name).toList();

    // Duplicate paths.
    final byPath = <String, List<RouteDeclaration>>{};
    for (final route in routes) {
      byPath.putIfAbsent(route.path, () => []).add(route);
    }
    for (final entry in byPath.entries) {
      if (entry.value.length > 1) {
        final classes = entry.value.map((r) => r.viewClassName).join(', ');
        errors.add(
          RouteCompilationError(
            message:
                'Duplicate route path ${entry.key} declared by '
                '$classes — every @Route path must be unique.',
            filePath: entry.value.first.filePath,
            line: entry.value.first.line,
          ),
        );
      }
    }

    // Missing parents + cycles.
    final byName = <String, RouteDeclaration>{
      for (final route in routes) route.name: route,
    };
    for (final route in routes) {
      final parent = route.parent;
      if (parent == null) continue;
      if (!byName.containsKey(parent)) {
        errors.add(
          RouteCompilationError(
            message:
                'Route ${route.viewClassName} (${route.path}) references '
                'parent route "$parent" which does not exist. Available '
                'parents: ${names.join(', ')}.',
            filePath: route.filePath,
            line: route.line,
          ),
        );
      }
    }
    _detectCycles(routes, byName, errors);

    // Param types + path coverage.
    for (final route in routes) {
      final pathParams = route.pathParameterNames.toSet();
      for (final entry in route.params.entries) {
        if (!_supportedParamTypes.contains(entry.value)) {
          errors.add(
            RouteCompilationError(
              message:
                  'Unsupported parameter type "${entry.value}" for '
                  ':${entry.key} on ${route.viewClassName} (${route.path}). '
                  'Supported types: ${_supportedParamTypes.join(', ')}.',
              filePath: route.filePath,
              line: route.line,
            ),
          );
        }
        if (!pathParams.contains(entry.key)) {
          errors.add(
            RouteCompilationError(
              message:
                  'Parameter "${entry.key}" on ${route.viewClassName} is '
                  'not present in the path ${route.path} — add a :${entry.key} '
                  'segment or remove the params entry.',
              filePath: route.filePath,
              line: route.line,
            ),
          );
        }
      }
    }

    // Redirect targets must exist.
    for (final redirect in scan.redirects) {
      if (!routePaths.contains(redirect.to)) {
        errors.add(
          RouteCompilationError(
            message:
                'Redirect from ${redirect.from} targets ${redirect.to} '
                'which is not a declared route path.',
            filePath: redirect.filePath,
            line: redirect.line,
          ),
        );
      }
    }

    // Guard classes must resolve to a known class.
    for (final route in routes) {
      for (final guard in route.middleware) {
        if (!scan.classIndex.containsKey(guard)) {
          errors.add(
            RouteCompilationError(
              message:
                  'Guard class $guard on ${route.viewClassName} '
                  '(${route.path}) was not found in lib/ — declare the guard '
                  'class or fix the name.',
              filePath: route.filePath,
              line: route.line,
            ),
          );
        }
      }
    }

    // Controller type mismatch (SC-004).
    if (controllerSourceOf != null) {
      for (final route in routes) {
        if (route.params.isEmpty) continue;
        final controllerSource = controllerSourceOf(route);
        if (controllerSource == null) continue;
        _checkControllerTypes(route, controllerSource, errors);
      }
    }

    return errors;
  }

  static bool _isNonViewIssue(RouteScanIssue issue) =>
      issue.message.contains('non-View class');

  static void _detectCycles(
    List<RouteDeclaration> routes,
    Map<String, RouteDeclaration> byName,
    List<RouteCompilationError> errors,
  ) {
    final visiting = <String>{};
    final visited = <String>{};

    void visit(String name) {
      if (visited.contains(name)) return;
      if (!visiting.add(name)) {
        errors.add(
          RouteCompilationError(
            message:
                'Parent route cycle detected involving "$name". Route '
                'parents must form a tree (a route cannot be its own '
                'ancestor).',
            filePath: byName[name]?.filePath ?? 'unknown.dart',
            line: byName[name]?.line ?? 1,
          ),
        );
        return;
      }
      final route = byName[name];
      final parent = route?.parent;
      if (parent != null && byName.containsKey(parent)) {
        visit(parent);
      }
      visiting.remove(name);
      visited.add(name);
    }

    for (final route in routes) {
      visit(route.name);
    }
  }

  /// SC-004: when the sibling Controller declares a field or constructor
  /// parameter with the same name as a typed route parameter but a
  /// different type, generation would produce a type mismatch — fail the
  /// build naming both types.
  static void _checkControllerTypes(
    RouteDeclaration route,
    String controllerSource,
    List<RouteCompilationError> errors,
  ) {
    final controllerName = _controllerNameFor(route.viewClassName);
    if (!_containsClass(controllerSource, controllerName)) return;

    for (final entry in route.params.entries) {
      final declaredType = _declaredTypeOfMember(
        controllerSource,
        controllerName,
        entry.key,
      );
      if (declaredType == null) continue;
      if (declaredType != entry.value) {
        errors.add(
          RouteCompilationError(
            message:
                'Route parameter type mismatch: @Route on '
                '${route.viewClassName} declares :${entry.key} as '
                '"${entry.value}" but $controllerName declares it as '
                '"$declaredType". Align the types to keep RouteParams '
                'compile-time safe.',
            filePath: route.filePath,
            line: route.line,
          ),
        );
      }
    }
  }

  static String _controllerNameFor(String viewClassName) {
    if (viewClassName.endsWith('View') && viewClassName.length > 4) {
      return '${viewClassName.substring(0, viewClassName.length - 4)}'
          'Controller';
    }
    return '${viewClassName}Controller';
  }

  static bool _containsClass(String source, String className) {
    return RegExp('class\\s+$className\\b').hasMatch(source);
  }

  /// Finds `final <Type> <name>;` fields and `this.<name>` constructor
  /// params (with their declared types) inside [className]'s body.
  static String? _declaredTypeOfMember(
    String source,
    String className,
    String memberName,
  ) {
    final classMatch = RegExp(
      'class\\s+$className\\b([^{]*)\\{',
    ).firstMatch(source);
    if (classMatch == null) return null;
    final bodyStart = classMatch.end;
    // Body ends at the matching close brace (approximate: next top-level
    // `class ` or end of source).
    final nextClass = source.indexOf(RegExp(r'\nclass\s'), bodyStart);
    final body = source.substring(
      bodyStart,
      nextClass < 0 ? source.length : nextClass,
    );

    // final <Type> name;
    final fieldMatch = RegExp(
      'final\\s+([A-Za-z_][A-Za-z0-9_<>?]*)\\s+$memberName\\s*[;=]',
    ).firstMatch(body);
    if (fieldMatch != null) return fieldMatch.group(1);

    // Constructor params with an EXPLICIT type: `<Type> this.name`.
    // Bare `this.name` (no explicit type) takes its type from the field
    // declaration above — if the field is absent there is no signal.
    final paramMatch = RegExp(
      '([A-Za-z_][A-Za-z0-9_<>?]*)\\s+this\\s*\\.\\s*$memberName\\b',
    ).firstMatch(body);
    if (paramMatch != null) return paramMatch.group(1);

    return null;
  }
}
