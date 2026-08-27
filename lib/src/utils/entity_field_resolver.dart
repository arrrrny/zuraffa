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
// Background (issue #307): the old resolution order fell back to the FIRST
// declared field when no id-like field existed. For id-less entities whose
// first field is an enum (`ChatMessage.role`, `TelemetryEvent.type`) that
// produced enum-typed ids in generated update/toggle signatures plus
// missing enum imports. The first-field fallback is now REMOVED: an
// entity without a real identity must either declare an id-like field,
// opt into `@Zorphy(autoId: true)`, or be a value object
// (`@ZValueObject` / `kind: ZorphyKind.valueObject`) — anything else is
// reported as an id-less entity and `zfa make` fails loudly.
//
// Resolution order:
//   1. a field literally named `id`
//   2. the first field whose name ends with `Id` (e.g. `depotId`, `userId`)
//   3. the synthetic `id: String` when the annotation has `autoId: true`
//
// [resolveIdField] returns null only when the entity file cannot be
// located or contains no parseable field declarations; in that case the
// caller keeps its existing default (`'id'`).

import 'dart:io';
import 'package:path/path.dart' as p;

/// The semantic kind of a Zorphy class, read from its annotation.
///
/// Mirrors `ZorphyKind` from the annotation package using source-text
/// detection so the resolver stays dependency-light.
enum EntitySourceKind { entity, valueObject }

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

/// The result of resolving an entity's identity: its kind, whether it
/// opts into `autoId`, and the resolved id-like field (if any).
///
/// [idField] is null for value objects (no identity required) and for
/// entities that declare neither an id-like field nor `autoId` — callers
/// must treat the latter as a loud error (see `zfa make`).
class EntityIdResolution {
  /// The semantic kind of the entity.
  final EntitySourceKind kind;

  /// Whether the annotation carries `autoId: true`.
  final bool autoId;

  /// The resolved id-like field, or null when the entity has no identity
  /// (value objects) or none could be resolved (id-less entity).
  final EntityFieldInfo? idField;

  const EntityIdResolution({
    required this.kind,
    required this.autoId,
    this.idField,
  });

  /// True when this is a value object (no id needed, no CRUD surface).
  bool get isValueObject => kind == EntitySourceKind.valueObject;

  /// True when an identity field is available — either a real source field
  /// or the synthetic `id: String` promised by `autoId: true`.
  bool get hasId => idField != null || autoId;
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
  static EntityIdResolution? resolveIdField({
    required String entityName,
    required String projectRoot,
    String entityOutputDir = defaultEntityOutputDir,
  }) {
    final snake = _toSnake(entityName);
    final entityFile = File(
      p.join(projectRoot, entityOutputDir, snake, '$snake.dart'),
    );
    if (!entityFile.existsSync()) return null;

    final content = entityFile.readAsStringSync();
    final fields = parseEntityFields(content);
    if (fields.isEmpty) return null;

    final autoId = detectsAutoId(content);
    final kind = detectsValueObject(content)
        ? EntitySourceKind.valueObject
        : EntitySourceKind.entity;

    // Value objects have no identity — never resolve (or invent) an id.
    if (kind == EntitySourceKind.valueObject) {
      return EntityIdResolution(kind: kind, autoId: autoId);
    }

    // 1. literal `id`
    for (final f in fields) {
      if (f.name == 'id') {
        return EntityIdResolution(kind: kind, autoId: autoId, idField: f);
      }
    }
    // 2. first ending in `Id` (camelCase, length > 2 to avoid matching `Id`)
    for (final f in fields) {
      if (f.name.length > 2 && f.name.endsWith('Id')) {
        return EntityIdResolution(kind: kind, autoId: autoId, idField: f);
      }
    }
    // 3. synthetic `id: String` promised by `autoId: true` (issue #307 —
    //    the generator defaults the concrete constructor's id to a uuid).
    if (autoId) {
      return EntityIdResolution(
        kind: kind,
        autoId: autoId,
        idField: const EntityFieldInfo(name: 'id', type: 'String'),
      );
    }

    // No identity: id-less entity. `zfa make` must fail loudly.
    return EntityIdResolution(kind: kind, autoId: autoId);
  }

  /// Resolves a representative REAL field of an id-less entity to use as
  /// the query/filter key on id-NEUTRAL plugin paths (issue #508:
  /// `zfa make <Entity> --test` regenerates test files from
  /// already-generated usecases and needs no identity — but its emitted
  /// tests must still reference a `Field` constant that actually exists on
  /// the entity).
  ///
  /// Selection order (declaration order within each tier):
  ///   1. first non-nullable `String`
  ///   2. first non-nullable `int`
  ///   3. first nullable `String?` / `int?`
  ///   4. first other scalar (`double`, `num`, `bool`, `DateTime`)
  /// Never selects an enum-typed (or any custom-class-typed) field — the
  /// pre-#307 first-field fallback produced enum-typed ids from exactly
  /// that mistake — and never invents a synthetic `id`. Returns `null`
  /// when the entity file cannot be located or has no usable scalar field;
  /// callers then keep their existing defaults.
  static EntityFieldInfo? resolveRepresentativeField({
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

    EntityFieldInfo? firstNullableStringOrInt;
    EntityFieldInfo? firstOtherScalar;
    for (final f in fields) {
      final type = f.nonNullableType;
      switch (type) {
        case 'String':
          if (!f.type.endsWith('?')) return f;
          firstNullableStringOrInt ??= f;
        case 'int':
          if (!f.type.endsWith('?')) return f;
          firstNullableStringOrInt ??= f;
        case 'double':
        case 'num':
        case 'bool':
        case 'DateTime':
          firstOtherScalar ??= f;
      }
    }
    return firstNullableStringOrInt ?? firstOtherScalar;
  }

  /// Detects `autoId: true` inside a `@Zorphy(...)`/`@Zorphy2(...)`
  /// annotation in [content].
  static bool detectsAutoId(String content) {
    final match = _zorphyAnnotationPattern.firstMatch(content);
    final args = match?.group(1);
    if (args == null) return false;
    return RegExp(r'\bautoId\s*:\s*true\b').hasMatch(args);
  }

  /// Detects a value-object kind in [content]: either the `@ZValueObject`
  /// annotation alias or `kind: ZorphyKind.valueObject` inside
  /// `@Zorphy(...)`.
  static bool detectsValueObject(String content) {
    if (RegExp(r'@\s*ZValueObject\b').hasMatch(content)) return true;
    final match = _zorphyAnnotationPattern.firstMatch(content);
    final args = match?.group(1);
    if (args == null) return false;
    return RegExp(
      r'\bkind\s*:\s*(?:ZorphyKind\.)?valueObject\b',
    ).hasMatch(args);
  }

  /// Matches `@Zorphy(...)` / `@zorphy(...)` / `@Zorphy2(...)` annotation
  /// invocations (with or without an argument list).
  static final RegExp _zorphyAnnotationPattern = RegExp(
    r'@\s*(?:Zorphy|zorphy|Zorphy2)\s*(\(([^)]*)\))?',
  );

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
