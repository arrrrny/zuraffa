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
// Background (issue #321, supersedes #307): the previous resolution
// order's step 3 ("first declared field") silently picked an enum-typed
// field as the id (e.g. ChatMessage.role: ChatMessageRole), producing
// enum-typed ids (UpdateParams<ChatMessageRole, ...>) that required
// enum imports the generators never emitted → 48 analyze errors. The
// fix removes the silent first-field fallback entirely: when no `id` /
// `*Id` field exists and no `@Zorphy(autoId: true)` marker is present,
// the resolver returns null and `MakeCommand` errors loudly with a
// clear diagnostic (issue #321).
//
// Coordination with #320 (autoId framework): the resolver recognises
// `@Zorphy(autoId: true)` — the marker #320 will use to auto-generate a
// uuid id — and returns a synthetic `EntityFieldInfo(name: 'id', type:
// 'String')`. When #320 lands and entities get the marker, this branch
// already produces the correct id field; the loud-error path is never
// reached for autoId entities, so the behavior stays forward-compatible.
//
// Resolution order:
//   1. a field literally named `id`
//   2. the first field whose name ends with `Id` (e.g. `depotId`, `userId`)
//   3. `@Zorphy(autoId: true)` marker on the entity class — returns a
//      synthetic `id: String` field (the autoId framework will populate
//      it; #320 coordinates the runtime side).
//   4. null — no suitable id-like field found; the caller (MakeCommand)
//      errors loudly with a diagnostic, never silently falls back.
//
// The resolver also returns null when the entity file cannot be located
// or contains no parseable field declarations; in that case the caller
// keeps its existing default (`'id'`) for backwards compatibility with
// non-entity `zfa make` flows (e.g. custom usecases without an entity).

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

  /// Synthetic id field returned when an entity has the
  /// `@Zorphy(autoId: true)` marker but no explicit `id` / `*Id` field.
  /// The autoId framework (#320) will populate this field at runtime;
  /// for code-generation purposes it is a plain `String` id, so the
  /// generated signatures use `String` as the id type (no enum imports
  /// needed, no first-field fallback).
  static const EntityFieldInfo autoIdField = EntityFieldInfo(
    name: 'id',
    type: 'String',
  );

  /// Resolves the id field for [entityName] inside [projectRoot].
  ///
  /// Looks up `<projectRoot>/<entityOutputDir>/<snake(entityName)>/<snake(entityName)>.dart`.
  /// Returns `null` when the entity file does not exist, contains no
  /// parseable field declarations, OR contains fields but none of them
  /// is id-like (no `id`, no `*Id`) AND the entity has no
  /// `@Zorphy(autoId: true)` marker. In the last case the caller
  /// (`MakeCommand`) must error loudly — never silently fall back to the
  /// first field (issue #321).
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

    final source = entityFile.readAsStringSync();
    final fields = parseEntityFields(source);
    if (fields.isEmpty) return null;

    // 1. literal `id`
    for (final f in fields) {
      if (f.name == 'id') return f;
    }
    // 2. first ending in `Id` (camelCase, length > 2 to avoid matching `Id`)
    for (final f in fields) {
      if (f.name.length > 2 && f.name.endsWith('Id')) return f;
    }
    // 3. `@Zorphy(autoId: true)` marker — synthetic `id: String` field.
    //    Coordinates with #320: when the autoId framework lands, entities
    //    annotated with `@Zorphy(autoId: true)` get a uuid-populated `id`
    //    field at runtime. For code generation, treat it as a plain
    //    `String` id so no enum imports are emitted and no first-field
    //    fallback fires.
    if (_hasAutoIdMarker(source)) {
      return autoIdField;
    }
    // 4. No suitable id-like field and no autoId marker — return null.
    //    The caller (MakeCommand) errors loudly with a diagnostic that
    //    points the user at the three valid resolutions (add `id`, add
    //    `autoId: true`, pass `--id-field` explicitly). Never silently
    //    fall back to the first field (issue #321).
    return null;
  }

  /// Returns the parsed fields of [entityName] inside [projectRoot], or
  /// `null` when the entity file does not exist.
  ///
  /// Used by `MakeCommand` to distinguish two null-return cases from
  /// [resolveIdField]:
  ///   - entity file not found (this method returns `null`) → keep the
  ///     default `'id'` (backwards compat with non-entity flows)
  ///   - entity file found, has fields, but no id-like field and no
  ///     autoId marker (this method returns a non-empty list) → error
  ///     loudly with a diagnostic (issue #321)
  ///
  /// An empty list means the file was found but had no parseable field
  /// declarations — treat the same as "file not found" (keep defaults).
  static List<EntityFieldInfo>? parseEntityFieldsForEntity({
    required String entityName,
    required String projectRoot,
    String entityOutputDir = defaultEntityOutputDir,
  }) {
    final snake = _toSnake(entityName);
    final entityFile = File(
      p.join(projectRoot, entityOutputDir, snake, '$snake.dart'),
    );
    if (!entityFile.existsSync()) return null;
    return parseEntityFields(entityFile.readAsStringSync());
  }

  /// Detects the `@Zorphy(autoId: true)` marker in the entity source.
  ///
  /// Matches `@Zorphy(... autoId: true ...)` with any other named args
  /// before/after, single-line or multi-line (dotAll). The marker is the
  /// forward-compatible hook for #320's auto-generated uuid id framework:
  /// when #320 lands and entities get `@Zorphy(autoId: true)`, this
  /// resolver already returns a synthetic `id: String` field for them,
  /// so the loud-error path is never reached for autoId entities.
  static bool _hasAutoIdMarker(String source) {
    // Strip /* block comments */ so a commented-out `@Zorphy(autoId: true)`
    // does not match.
    final cleaned = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    // Also strip // line comments to be safe.
    final withoutLineComments = cleaned.replaceAll(
      RegExp(r'//[^\n]*'),
      '',
    );
    final re = RegExp(
      r'@Zorphy\s*\([^)]*\bautoId\s*:\s*true\b[^)]*\)',
      dotAll: true,
    );
    return re.hasMatch(withoutLineComments);
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
