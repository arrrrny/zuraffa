// entity_field_resolver.dart
//
// Resolves the identity of a Zorphy class by reading its source file.
// Used by `zfa make` to populate `id-field` / `query-field` defaults so
// that the generated presenter / test / datasource code references a
// field that actually exists on the entity's Fields class.
//
// The source is read through the analyzer AST and the v3 archetype annotations:
//
//   - `@ZorphyValue()` marks a value object: no identity, no CRUD
//     surface. An id-like field name on one is never resolved.
//   - `@ZorphyEntity(principalKey: #<field>)` declares the identity. The
//     named field wins over every naming convention.
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
// missing enum imports. The first-field fallback is REMOVED: an entity
// without a real identity is reported as id-less and `zfa make` fails
// loudly.
//
// Resolution order:
//   1. the `principalKey` field named by `@ZorphyEntity(...)`
//   2. a field literally named `id`
//   3. the first field whose name ends with `Id` (e.g. `depotId`, `userId`)
//
// A class carrying no v3 annotation (a hand-written Dart class) is read
// as an entity and resolved by 2 and 3.
//
// [resolveIdField] returns null only when the entity file cannot be
// located or contains no parseable field declarations; in that case the
// caller keeps its existing default (`'id'`).

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import 'string_utils.dart';

/// The semantic kind of a Zorphy class, read from its annotation.
///
/// Mirrors `ZorphyKind` from the annotation package using class metadata.
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

/// The result of resolving a class's identity: its kind and the resolved
/// id-like field (if any).
///
/// [idField] is null for value objects (no identity required) and for
/// entities that declare no identity; callers must treat the latter as a
/// loud error (see `zfa make`).
class EntityIdResolution {
  /// The semantic kind of the entity.
  final EntitySourceKind kind;

  /// The resolved id-like field, or null when the entity has no identity
  /// (value objects) or none could be resolved (id-less entity).
  final EntityFieldInfo? idField;

  const EntityIdResolution({required this.kind, this.idField});

  /// True when this is a value object (no id needed, no CRUD surface).
  bool get isValueObject => kind == EntitySourceKind.valueObject;

  /// True when an identity field is available.
  bool get hasId => idField != null;
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

    return resolveFromSource(
      entityFile.readAsStringSync(),
      className: entityName,
    );
  }

  /// Resolves the identity declared in [content], the source of a Zorphy
  /// class. Returns null when it has no parseable field declarations.
  ///
  /// The one resolution every surface consults (`zfa make`, the tdd make
  /// gate, the entity analyzer) — see the file doc comment for the order.
  static EntityIdResolution? resolveFromSource(
    String content, {
    String? className,
  }) {
    final unit = _parseCompilationUnit(content);
    if (unit == null) return null;
    final classes = unit.declarations.whereType<ClassDeclaration>().toList();
    final declaration = _findDeclaration(
      classes: classes,
      className: className,
    );
    if (declaration == null) return null;
    final fields = _fieldsForDeclaration(declaration, classes);
    if (fields.isEmpty) return null;

    // Value objects have no identity — never resolve (or invent) an id.
    if (_archetypeOf(declaration) == 'ZorphyValue') {
      return const EntityIdResolution(kind: EntitySourceKind.valueObject);
    }
    const kind = EntitySourceKind.entity;

    // 1. the `principalKey` field the annotation declares
    final principalKey =
        _principalKeyOf(declaration) ??
        _inheritedPrincipalKey(declaration, classes);
    if (principalKey != null) {
      for (final f in fields) {
        if (f.name == principalKey) {
          return EntityIdResolution(kind: kind, idField: f);
        }
      }
    }
    // 2. literal `id`
    for (final f in fields) {
      if (f.name == 'id') {
        return EntityIdResolution(kind: kind, idField: f);
      }
    }
    // 3. first ending in `Id` (camelCase, length > 2 to avoid matching `Id`)
    for (final f in fields) {
      if (f.name.length > 2 && f.name.endsWith('Id')) {
        return EntityIdResolution(kind: kind, idField: f);
      }
    }

    // No identity: id-less entity. `zfa make` must fail loudly.
    return const EntityIdResolution(kind: kind);
  }

  /// Returns true when a source file for [entityName] exists at the
  /// canonical location `<projectRoot>/<entityOutputDir>/<snake>/<snake>.dart`.
  ///
  /// `zfa make` uses this to distinguish the MISSING-FILE case (the entity
  /// was never created) from an id-less entity whose file EXISTS (issue
  /// #307/#508/#514) so only the former fails fast. The two cases are
  /// otherwise indistinguishable from [resolveIdField], which returns null
  /// for both a missing file and a file with no parseable fields.
  static bool entityFileExists({
    required String entityName,
    required String projectRoot,
    String entityOutputDir = defaultEntityOutputDir,
  }) {
    final snake = _toSnake(entityName);
    final entityFile = File(
      p.join(projectRoot, entityOutputDir, snake, '$snake.dart'),
    );
    return entityFile.existsSync();
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

    final fields = parseEntityFields(
      entityFile.readAsStringSync(),
      className: entityName,
    );
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

  /// True when [content] declares the v3 value-object archetype
  /// (`@ZorphyValue`). Comments and string literals do not classify the class.
  static bool detectsValueObject(String content) {
    final unit = _parseCompilationUnit(content);
    if (unit == null) return false;
    final classes = unit.declarations.whereType<ClassDeclaration>().toList();
    return _archetypeOf(_findDeclaration(classes: classes)) == 'ZorphyValue';
  }

  /// The field named by `@ZorphyEntity(principalKey: #<field>)` in
  /// [content], or null when no principal key is declared there.
  static String? principalKeyField(String content) {
    final unit = _parseCompilationUnit(content);
    if (unit == null) return null;
    final classes = unit.declarations.whereType<ClassDeclaration>().toList();
    return _principalKeyOf(_findDeclaration(classes: classes));
  }

  /// Parses `<entity>.dart` source content for field declarations.
  ///
  /// Recognises instance fields and getters on the Zorphy class, plus the
  /// static `ZorphyField<Entity, Value>` constants on a generated
  /// `<Entity>Fields` descriptor. Returns fields in declaration order.
  static List<EntityFieldInfo> parseEntityFields(
    String content, {
    String? className,
  }) {
    final unit = _parseCompilationUnit(content);
    if (unit == null) return const [];
    final classes = unit.declarations.whereType<ClassDeclaration>().toList();
    final declaration = _findDeclaration(
      classes: classes,
      className: className,
    );
    return declaration == null
        ? const []
        : _fieldsForDeclaration(declaration, classes);
  }

  static ClassDeclaration? _findDeclaration({
    required List<ClassDeclaration> classes,
    String? className,
  }) {
    if (className != null) {
      final target = _cleanClassName(className);
      for (final declaration in classes) {
        if (_cleanClassName(declaration.namePart.typeName.lexeme) == target) {
          return declaration;
        }
      }
    }
    for (final declaration in classes) {
      if (_archetypeOf(declaration) == 'ZorphyEntity') return declaration;
    }
    for (final declaration in classes) {
      if (_archetypeOf(declaration) == 'ZorphyValue') return declaration;
    }
    for (final declaration in classes) {
      if (!declaration.namePart.typeName.lexeme.endsWith('Fields') ||
          _descriptorFields(declaration).isEmpty) {
        continue;
      }
      return _concreteClassForDescriptor(declaration, classes) ?? declaration;
    }
    for (final declaration in classes) {
      if (_instanceFields(declaration).isNotEmpty) return declaration;
    }
    return classes.isNotEmpty ? classes.first : null;
  }

  static CompilationUnit? _parseCompilationUnit(String content) {
    try {
      var result = parseString(content: content, throwIfDiagnostics: false);
      // Annotation-only helper inputs need a declaration for analyzer metadata.
      if (result.unit.declarations.whereType<ClassDeclaration>().isEmpty &&
          content.trim().isNotEmpty) {
        result = parseString(
          content: '$content\nclass _ZorphyResolverProbe {}',
          throwIfDiagnostics: false,
        );
      }
      return result.unit;
    } catch (_) {
      return null;
    }
  }

  static List<EntityFieldInfo> _fieldsForDeclaration(
    ClassDeclaration declaration,
    List<ClassDeclaration> classes,
  ) {
    if (declaration.namePart.typeName.lexeme.endsWith('Fields')) {
      final descriptors = _descriptorFields(declaration);
      if (descriptors.isNotEmpty) return descriptors;
    }
    final cleanName = _cleanClassName(declaration.namePart.typeName.lexeme);
    for (final candidate in classes) {
      if (candidate.namePart.typeName.lexeme != '${cleanName}Fields') continue;
      final descriptors = _descriptorFields(candidate);
      if (descriptors.isNotEmpty) return descriptors;
    }
    return _instanceFields(declaration);
  }

  static List<EntityFieldInfo> _instanceFields(ClassDeclaration declaration) {
    final fields = <EntityFieldInfo>[];
    for (final member in declaration.body.members) {
      if (member is FieldDeclaration && !member.isStatic) {
        final type = member.fields.type;
        if (type == null) continue;
        for (final variable in member.fields.variables) {
          fields.add(
            EntityFieldInfo(name: variable.name.lexeme, type: type.toSource()),
          );
        }
      } else if (member is MethodDeclaration &&
          member.isGetter &&
          !member.isStatic) {
        final type = member.returnType;
        if (type == null) continue;
        fields.add(
          EntityFieldInfo(name: member.name.lexeme, type: type.toSource()),
        );
      }
    }
    return fields;
  }

  static List<EntityFieldInfo> _descriptorFields(ClassDeclaration declaration) {
    final fields = <EntityFieldInfo>[];
    for (final member in declaration.body.members) {
      if (member is! FieldDeclaration || !member.isStatic) continue;
      final type = member.fields.type;
      if (type is! NamedType || type.name.lexeme != 'ZorphyField') continue;
      final arguments = type.typeArguments?.arguments;
      if (arguments == null || arguments.length < 2) continue;
      final valueType = arguments[1].toSource();
      for (final variable in member.fields.variables) {
        fields.add(
          EntityFieldInfo(name: variable.name.lexeme, type: valueType),
        );
      }
    }
    return fields;
  }

  static ClassDeclaration? _concreteClassForDescriptor(
    ClassDeclaration descriptor,
    List<ClassDeclaration> classes,
  ) {
    final descriptorName = descriptor.namePart.typeName.lexeme;
    final entityName = descriptorName.substring(
      0,
      descriptorName.length - 'Fields'.length,
    );
    for (final declaration in classes) {
      if (_cleanClassName(declaration.namePart.typeName.lexeme) == entityName) {
        return declaration;
      }
    }
    return null;
  }

  static String _cleanClassName(String name) {
    var clean = name;
    while (clean.startsWith(r'$')) {
      clean = clean.substring(1);
    }
    return clean;
  }

  static String? _inheritedPrincipalKey(
    ClassDeclaration declaration,
    List<ClassDeclaration> classes,
  ) {
    final byName = {
      for (final candidate in classes)
        _cleanClassName(candidate.namePart.typeName.lexeme): candidate,
    };
    final visited = <String>{};

    String? visit(ClassDeclaration current) {
      for (final supertype in _supertypes(current)) {
        final base = byName[_cleanClassName(supertype.name.lexeme)];
        if (base == null) continue;
        final name = _cleanClassName(base.namePart.typeName.lexeme);
        if (!visited.add(name)) continue;
        final key = _principalKeyOf(base);
        if (key != null) return key;
        final inherited = visit(base);
        if (inherited != null) return inherited;
      }
      return null;
    }

    return visit(declaration);
  }

  static String? _archetypeOf(ClassDeclaration? declaration) {
    if (declaration == null) return null;
    for (final annotation in declaration.metadata) {
      final name = annotation.name.name.split('.').last;
      if (name == 'ZorphyEntity' || name == 'ZorphyValue') return name;
    }
    if (_hasArchetypeBase(declaration, 'ZorphyValueBase')) return 'ZorphyValue';
    if (_hasArchetypeBase(declaration, 'ZorphyEntityBase')) {
      return 'ZorphyEntity';
    }
    return null;
  }

  static bool _hasArchetypeBase(ClassDeclaration declaration, String baseName) {
    return _supertypes(declaration).any((type) => type.name.lexeme == baseName);
  }

  static Iterable<NamedType> _supertypes(ClassDeclaration declaration) sync* {
    final extendsClause = declaration.extendsClause;
    if (extendsClause != null) {
      yield extendsClause.superclass;
    }
    final withClause = declaration.withClause;
    if (withClause != null) {
      yield* withClause.mixinTypes;
    }
    final implementsClause = declaration.implementsClause;
    if (implementsClause != null) {
      yield* implementsClause.interfaces;
    }
  }

  static String? _principalKeyOf(ClassDeclaration? declaration) {
    if (declaration == null) return null;
    for (final annotation in declaration.metadata) {
      if (annotation.name.name.split('.').last != 'ZorphyEntity') continue;
      final arguments = annotation.arguments?.arguments;
      if (arguments == null) continue;
      for (final argument in arguments) {
        if (argument is! NamedArgument ||
            argument.name.lexeme != 'principalKey') {
          continue;
        }
        final value = argument.argumentExpression;
        if (value is SymbolLiteral && value.components.length == 1) {
          return value.components.single.lexeme;
        }
      }
    }
    return null;
  }

  /// Converts a PascalCase / camelCase name to snake_case — DELEGATED to
  /// [StringUtils.camelToSnake], the exact function `zfa entity create`
  /// uses for its output path, so the lookup is consistent with what the
  /// writer lays down for EVERY accepted name (issue #872).
  ///
  /// Bug #872: the previous hand-rolled loop underscored before ANY
  /// uppercase-equal char — including digits — so it produced `a_1` for
  /// `A1` while `entity create` wrote `a1/a1.dart`, and `zfa make` failed
  /// fast with "no entity source file was found" for an entity that
  /// existed on disk. Delegating to the writer's own function makes the
  /// two surfaces structurally unable to drift again.
  static String _toSnake(String input) {
    // Strip a leading `$` (Zorphy prefix for abstract entity classes).
    var s = input;
    while (s.startsWith(r'$')) {
      s = s.substring(1);
    }
    return StringUtils.camelToSnake(s);
  }
}
