/// Naming conventions and reserved-word handling for GraphQL → Dart
/// identifier generation (spec 037 FR-007).
///
/// Conventions:
/// - Field/variable names: camelCase.
/// - Class/type names: PascalCase.
///
/// Reserved-word handling (documented escapes):
/// - A field name that collides with a Dart keyword or built-in type
///   identifier is prefixed with `_$` (e.g. `class` → `_$class`,
///   `int` → `_$int`) — valid Dart that cannot collide with language
///   constructs.
/// - A class name that collides with a built-in Dart type name (in its
///   PascalCase rendering) is suffixed with `$` (e.g. `int` → `Int$`,
///   `String` → `String$`).
library;

class DartTypeNamer {
  DartTypeNamer._();

  /// Dart language keywords and contextual keywords that are invalid or
  /// dangerous as field/variable identifiers (camelCase forms).
  static const Set<String> _reservedFieldWords = {
    'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
    'catch', 'class', 'const', 'continue', 'covariant', 'default',
    'deferred', 'do', 'dynamic', 'else', 'enum', 'export', 'extends',
    'extension', 'external', 'factory', 'false', 'final', 'finally', 'for',
    'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is',
    'late', 'library', 'mixin', 'new', 'null', 'on', 'operator', 'part',
    'required', 'rethrow', 'return', 'sealed', 'set', 'show', 'static',
    'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'typedef',
    'var', 'void', 'when', 'while', 'with', 'yield',
    // Built-in type identifiers — invalid as declared variable names.
    // ('set', 'object' and 'function' are already in the keyword list.)
    'int', 'double', 'num', 'bool', 'string', 'list', 'map',
  };

  /// PascalCase renderings of built-in Dart types — shadowing these with a
  /// generated class would break or confuse generated imports.
  static const Set<String> _reservedClassWords = {
    'String',
    'Int',
    'Double',
    'Num',
    'Bool',
    'Dynamic',
    'List',
    'Map',
    'Set',
    'Object',
    'Null',
    'Function',
    'Void',
  };

  /// Converts a GraphQL field name to a Dart field name (camelCase,
  /// reserved words escaped with the documented `_$` prefix).
  static String fieldName(String graphQLName) {
    final camel = _toCamelCase(graphQLName);
    if (_reservedFieldWords.contains(camel)) {
      return '_\$$camel';
    }
    return camel;
  }

  /// Converts a GraphQL type name to a Dart class name (PascalCase,
  /// built-in type collisions escaped with the documented `$` suffix).
  static String className(String graphQLName) {
    final pascal = _toPascalCase(graphQLName);
    if (_reservedClassWords.contains(pascal)) {
      return '$pascal\$';
    }
    return pascal;
  }

  /// `snake_case`/`kebab-case`/`SCREAMING_CASE`/`PascalCase` → camelCase.
  static String _toCamelCase(String name) {
    final segments = _split(name);
    if (segments.isEmpty) return name;
    if (segments.length == 1) {
      return _lowerFirst(segments.first);
    }
    final head = _lowerFirst(segments.first);
    final tail = segments.skip(1).map(_upperFirst).join();
    return '$head$tail';
  }

  /// `snake_case`/`kebab-case`/`lowercase` → PascalCase.
  static String _toPascalCase(String name) {
    final segments = _split(name);
    if (segments.isEmpty) return name;
    return segments.map(_upperFirst).join();
  }

  static List<String> _split(String name) {
    return name
        .replaceAll(RegExp(r'[^0-9a-zA-Z]+'), '_')
        .split('_')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Lowercases the first character; ALL-CAPS acronyms (e.g. `SKU`)
  /// lowercase entirely.
  static String _lowerFirst(String segment) {
    if (segment.isEmpty) return segment;
    if (segment == segment.toUpperCase()) {
      // Acronym or SCREAMING segment: `SKU` -> `sku`, `ID` -> `id`.
      return segment.toLowerCase();
    }
    return segment[0].toLowerCase() + segment.substring(1);
  }

  /// Uppercases the first character; ALL-CAPS acronyms keep screaming form
  /// only when the whole segment is a single acronym mid-name? No — for
  /// class rendering we normalize acronyms to Pascal (`ORDER` -> `Order`).
  static String _upperFirst(String segment) {
    if (segment.isEmpty) return segment;
    if (segment == segment.toUpperCase()) {
      return segment[0] + segment.substring(1).toLowerCase();
    }
    return segment[0].toUpperCase() + segment.substring(1);
  }
}
