import 'package:analyzer/dart/ast/ast.dart';
import 'package:meta/meta.dart';

/// Represents a parsed decorator annotation found on a class, method,
/// or field declaration.
///
/// [DecoratorAST] extracts the decorator name, all named/positional arguments,
/// and supports `fromYaml` references for complex configuration.
@immutable
class DecoratorAST {
  const DecoratorAST({
    required this.name,
    required this.target,
    this.positionalArgs = const [],
    this.namedArgs = const {},
    this.yamlReference,
    this.sourceLocation,
  });

  /// The decorator name without the `@` prefix, e.g. `Cacheable`, `XRayMock`.
  final String name;

  /// The AST node this decorator is attached to.
  final AstNode target;

  /// Positional arguments passed to the decorator constructor.
  final List<dynamic> positionalArgs;

  /// Named arguments passed to the decorator constructor.
  final Map<String, dynamic> namedArgs;

  /// If the decorator uses `@Decorator.fromYaml('path.yaml')`, this holds
  /// the resolved YAML content as a Map. Null otherwise.
  final Map<String, dynamic>? yamlReference;

  /// Source location for error reporting.
  final SourceLocation? sourceLocation;

  /// Whether this decorator has a `fromYaml` reference.
  bool get hasYamlReference => yamlReference != null;

  /// Get a named argument by key, or [defaultValue] if absent.
  T? get<T>(String key, {T? defaultValue}) {
    final value = namedArgs[key];
    if (value == null) return defaultValue;
    if (value is T) return value;
    throw DecoratorParseError(
      'Argument "$key" expected type $T but got ${value.runtimeType}',
      sourceLocation: sourceLocation,
    );
  }

  /// Get a required named argument. Throws if absent.
  T require<T>(String key) {
    final value = namedArgs[key];
    if (value == null) {
      throw DecoratorParseError(
        'Missing required argument "$key" on @$name',
        sourceLocation: sourceLocation,
      );
    }
    if (value is T) return value;
    throw DecoratorParseError(
      'Argument "$key" expected type $T but got ${value.runtimeType}',
      sourceLocation: sourceLocation,
    );
  }

  @override
  String toString() =>
      'DecoratorAST(@$name, positional=$positionalArgs, named=$namedArgs, '
      'yaml=$yamlReference)';
}

/// Location within a source file for precise error reporting.
@immutable
class SourceLocation {
  const SourceLocation({
    required this.filePath,
    required this.line,
    required this.column,
    this.offset,
  });

  final String filePath;
  final int line;
  final int column;
  final int? offset;

  @override
  String toString() => '$filePath:$line:$column';
}

/// Error thrown when decorator parsing fails.
class DecoratorParseError implements Exception {
  const DecoratorParseError(this.message, {this.sourceLocation});
  final String message;
  final SourceLocation? sourceLocation;

  @override
  String toString() =>
      '[DecoratorParseError] $message${sourceLocation != null ? ' at $sourceLocation' : ''}';
}
