// entity_field_resolver.dart
//
// Resolves the id-like field of a Zorphy entity by reading the entity's
// source file. Used by `zfa make` to populate `id-field` / `query-field`
// defaults so that the generated presenter / test / datasource code
// references a field that actually exists on the entity's Fields class.
//
// Background (issue #294): before this fix, the generators hardcoded
// `EntityFields.id` regardless of the entity's actual fields. Entities
// like `StorePrice` (whose id field is `depotId`) produced broken
// generated code that referenced `StorePriceFields.id` (undefined getter).
//
// Resolution order:
//   1. a field literally named `id`
//   2. the first field whose name ends with `Id` (e.g. `depotId`, `userId`)
//   3. the first declared field
//
// The resolver returns null when the entity file cannot be located or
// contains no parseable field declarations; in that case the caller
// keeps its existing default (`'id'`).

import 'dart:io';
import 'package:path/path.dart' as p;

/// A single parsed field declaration: a Dart type string and a field name.
class EntityFieldInfo {
  /// Field name as it appears in the entity source (e.g. `depotId`, `id`).
  final String name;

  /// Field type as written in the entity source (e.g. `String`, `int?`,
  /// `Map<String, dynamic>`). Nullable trailing `?` is preserved.
  final String type;

  const EntityFieldInfo({required this.name, required this.type});

  /// Strips a trailing `?` from [type] to produce a non-nullable type
  /// string. Used when feeding the value into `idFieldType` (which is
  /// conventionally a non-nullable type token like `String`).
  String get nonNullableType {
    var t = type.trim();
    while (t.endsWith('?')) {
      t = t.substring(0, t.length - 1).trim();
    }
    return t;
  }

  @override
  String toString() => 'EntityFieldInfo(name: $name, type: $type)';
}

/// Reads a Zorphy entity source file and resolves the entity's id-like
/// field. See the file doc comment for the resolution order.
class EntityFieldResolver {
  /// Default location of entity source files relative to the project root.
  static const String defaultEntityOutputDir = 'lib/src/domain/entities';

  /// Resolves the id field for [entityName] inside [projectRoot].
  ///
  /// Looks up `<projectRoot>/<entityOutputDir>/<snake(entityName)>/<snake(entityName)>.dart`.
  /// Returns `null` when the entity file does not exist or contains no
  /// parseable field declarations.
  ///
  /// [entityOutputDir] defaults to [defaultEntityOutputDir] but can be
  /// overridden (e.g. in tests).
  static EntityFieldInfo? resolveIdField({
    required String entityName,
    required String projectRoot,
    String entityOutputDir = defaultEntityOutputDir,
  }) {
    final snake = _toSnake(entityName);
    final entityFile = File(
      p.join(projectRoot, entityOutputDir, snake, '$snake.dart'),
    );
    if (!entityFile.existsSync()) return null;

    final fields = parseEntityFields(entityFile.readAsStringSync());
    if (fields.isEmpty) return null;

    // 1. literal `id`
    for (final f in fields) {
      if (f.name == 'id') return f;
    }
    // 2. first ending in `Id` (camelCase, length > 2 to avoid matching `Id`)
    for (final f in fields) {
      if (f.name.length > 2 && f.name.endsWith('Id')) return f;
    }
    // 3. first declared field
    return fields.first;
  }

  /// Parses `<entity>.dart` source content for field declarations.
  ///
  /// Recognises both forms emitted by `zfa entity create`:
  ///   - `  Type get fieldName;`     (Zorphy abstract entity, the default)
  ///   - `  final Type fieldName;`   (concrete class hand-written)
  ///   - `  Type fieldName;`        (concrete class without final)
  ///
  /// Returns the list of [EntityFieldInfo] in declaration order.
  /// Comments and method bodies are ignored.
  static List<EntityFieldInfo> parseEntityFields(String content) {
    final fields = <EntityFieldInfo>[];

    // Strip /* block comments */ so the regex does not match field-like
    // text inside them.
    final cleaned = content.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

    // Match a single line of the form `  Type get fieldName;` OR
    // `  final Type fieldName;` OR `  Type fieldName;`.
    //
    // Group 1 = type (greedy enough to include `Map<String, dynamic>?`)
    // Group 2 = field name
    //
    // We require the line to start with whitespace (indentation inside a
    // class body) and to end with a semicolon, so we don't accidentally
    // pick up method declarations or top-level statements.
    final pattern = RegExp(
      r'^\s+(?:final\s+)?([A-Za-z_][\w<>?,\s]*?)\s+(?:get\s+)?([A-Za-z_]\w*)\s*;',
      multiLine: true,
    );

    for (final match in pattern.allMatches(cleaned)) {
      final type = match.group(1)!.trim();
      final name = match.group(2)!.trim();
      if (type.isEmpty || name.isEmpty) continue;
      // Skip well-known non-field keywords that the regex might catch.
      if (_reservedTypeTokens.contains(type)) continue;
      // Skip method-returning constructors like `MyClass` followed by what
      // looks like a parameter list — these are handled by the
      // `(?:get\s+)?` branch only when there is no `(`, which is already
      // enforced by the trailing `\s*;`.
      fields.add(EntityFieldInfo(name: name, type: type));
    }

    return fields;
  }

  /// Tokens that may appear in the type position of a class body line but
  /// are not actually field types (e.g. `static`, `const`, `void` for a
  /// method that happens to end with `;`). These are filtered out by
  /// [parseEntityFields].
  static const Set<String> _reservedTypeTokens = {
    'static',
    'const',
    'final',
    'void',
    'return',
    'if',
    'else',
    'for',
    'while',
    'switch',
    'case',
    'default',
  };

  /// Converts a PascalCase / camelCase name to snake_case (matches the
  /// `EntityConfig.snakeName` logic in zorphy so the file path lookup
  /// is consistent with what `zfa entity create` actually writes).
  static String _toSnake(String input) {
    if (input.isEmpty) return '';
    // Strip a leading `$` (Zorphy prefix for abstract entity classes).
    var s = input;
    while (s.startsWith(r'$')) {
      s = s.substring(1);
    }
    final result = <String>[];
    for (var i = 0; i < s.length; i += 1) {
      final char = s[i];
      if (i > 0 && char.toUpperCase() == char && char != '_') {
        result.add('_');
      }
      result.add(char.toLowerCase());
    }
    return result.join();
  }
}
