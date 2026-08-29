/// Breaking/non-breaking schema diff engine.
///
/// Spec 037 (FR-003): compare two [GqlSchema]s and classify every change:
///
/// **Breaking** (FR-003 + Edge Cases):
/// - removed type
/// - removed field
/// - changed nullability
/// - added required (non-null) field
/// - removed enum value
/// - changed field base type (defensive extra category)
///
/// **Non-breaking**:
/// - added optional (nullable) field
/// - added enum value
/// - added type
///
/// FR-004: the CLI maps [SchemaDiff.hasBreaking] to exit code 1, otherwise 0.
library;

import '../graphql_schema.dart';
import '../sdl/sdl_printer.dart';

enum ChangeSeverity { breaking, nonBreaking }

enum ChangeKind {
  typeRemoved,
  fieldRemoved,
  nullabilityChanged,
  requiredFieldAdded,
  enumValueRemoved,
  fieldTypeChanged,
  optionalFieldAdded,
  enumValueAdded,
  typeAdded,
}

/// A single detected difference between two schema versions.
class SchemaChange {
  const SchemaChange({
    required this.severity,
    required this.kind,
    required this.typeName,
    this.fieldName,
    this.detail,
  });

  final ChangeSeverity severity;
  final ChangeKind kind;

  /// The GraphQL type the change belongs to (or the added/removed type's
  /// own name).
  final String typeName;

  /// The field name (or enum value name) — null for type-level changes.
  final String? fieldName;

  /// Extra context (e.g. old → new type rendering).
  final String? detail;

  /// Human-readable description used by `zfa graphql diff`.
  String describe() {
    final where = fieldName == null ? typeName : '$typeName.$fieldName';
    final prefix = severity == ChangeSeverity.breaking
        ? '[breaking]'
        : '[non-breaking]';
    final message = switch (kind) {
      ChangeKind.typeRemoved => "Type '$typeName' was removed",
      ChangeKind.typeAdded => "Type '$typeName' was added",
      ChangeKind.fieldRemoved => "Field '$where' was removed",
      ChangeKind.requiredFieldAdded =>
        "Required field '$where' was added (${detail ?? ''})",
      ChangeKind.optionalFieldAdded =>
        "Optional field '$where' was added (${detail ?? ''})",
      ChangeKind.nullabilityChanged =>
        "Nullability of '$where' changed (${detail ?? ''})",
      ChangeKind.fieldTypeChanged =>
        "Type of '$where' changed (${detail ?? ''})",
      ChangeKind.enumValueAdded => "Enum value '$where' was added",
      ChangeKind.enumValueRemoved => "Enum value '$where' was removed",
    };
    return '$prefix $message';
  }

  @override
  String toString() => describe();
}

/// The result of diffing two schemas.
class SchemaDiff {
  const SchemaDiff(this.changes);

  /// All detected changes, in a deterministic order (per type, then fields,
  /// then enums, as iterated from the schema type maps).
  final List<SchemaChange> changes;

  /// Whether any breaking change exists (FR-004 exit-code input).
  bool get hasBreaking =>
      changes.any((c) => c.severity == ChangeSeverity.breaking);

  List<SchemaChange> get breakingChanges => changes
      .where((c) => c.severity == ChangeSeverity.breaking)
      .toList();
  List<SchemaChange> get nonBreakingChanges => changes
      .where((c) => c.severity == ChangeSeverity.nonBreaking)
      .toList();
}

class SchemaDiffer {
  SchemaDiffer._();

  /// Diffs [oldSchema] against [newSchema].
  static SchemaDiff diff(GqlSchema oldSchema, GqlSchema newSchema) {
    final changes = <SchemaChange>[];

    final oldTypes = oldSchema.types;
    final newTypes = newSchema.types;

    // Removed types — breaking.
    for (final name in oldTypes.keys) {
      if (!newTypes.containsKey(name)) {
        changes.add(SchemaChange(
          severity: ChangeSeverity.breaking,
          kind: ChangeKind.typeRemoved,
          typeName: name,
        ));
      }
    }

    // Added types — non-breaking.
    for (final name in newTypes.keys) {
      if (!oldTypes.containsKey(name)) {
        changes.add(SchemaChange(
          severity: ChangeSeverity.nonBreaking,
          kind: ChangeKind.typeAdded,
          typeName: name,
        ));
      }
    }

    // Field/enum changes for types present in both.
    final commonNames = oldTypes.keys
        .where(newTypes.containsKey)
        .toList(growable: false);
    for (final name in commonNames) {
      _diffType(oldTypes[name]!, newTypes[name]!, changes);
    }

    return SchemaDiff(changes);
  }

  static void _diffType(
    GqlTypeDef oldType,
    GqlTypeDef newType,
    List<SchemaChange> changes,
  ) {
    // Enum value sets.
    if (oldType.isEnum && newType.isEnum) {
      _diffEnums(oldType, newType, changes);
    }

    // Fields (objects, interfaces; input objects use inputFields).
    if (oldType.kind == newType.kind) {
      _diffFields(
        oldType,
        _fieldsOf(oldType),
        _fieldsOf(newType),
        changes,
      );
    }
  }

  static List<GqlField> _fieldsOf(GqlTypeDef type) {
    return type.fields ?? type.inputFields ?? const <GqlField>[];
  }

  static void _diffEnums(
    GqlTypeDef oldType,
    GqlTypeDef newType,
    List<SchemaChange> changes,
  ) {
    final oldValues = (oldType.enumValues ?? const <GqlEnumValue>[])
        .map((v) => v.name)
        .toSet();
    final newValues = (newType.enumValues ?? const <GqlEnumValue>[])
        .map((v) => v.name)
        .toSet();

    for (final value in oldValues) {
      if (!newValues.contains(value)) {
        changes.add(SchemaChange(
          severity: ChangeSeverity.breaking,
          kind: ChangeKind.enumValueRemoved,
          typeName: oldType.name,
          fieldName: value,
        ));
      }
    }
    for (final value in newValues) {
      if (!oldValues.contains(value)) {
        changes.add(SchemaChange(
          severity: ChangeSeverity.nonBreaking,
          kind: ChangeKind.enumValueAdded,
          typeName: newType.name,
          fieldName: value,
        ));
      }
    }
  }

  static void _diffFields(
    GqlTypeDef type,
    List<GqlField> oldFields,
    List<GqlField> newFields,
    List<SchemaChange> changes,
  ) {
    final oldByName = {for (final f in oldFields) f.name: f};
    final newByName = {for (final f in newFields) f.name: f};

    // Removed fields — breaking.
    for (final name in oldByName.keys) {
      if (!newByName.containsKey(name)) {
        changes.add(SchemaChange(
          severity: ChangeSeverity.breaking,
          kind: ChangeKind.fieldRemoved,
          typeName: type.name,
          fieldName: name,
        ));
      }
    }

    for (final entry in newByName.entries) {
      final field = entry.value;
      final oldField = oldByName[entry.key];

      if (oldField == null) {
        // Added field: required (non-null) breaks consumers, optional does not.
        final isRequired = field.type.isNonNull;
        final rendered = SdlPrinter.renderType(field.type);
        changes.add(SchemaChange(
          severity: isRequired
              ? ChangeSeverity.breaking
              : ChangeSeverity.nonBreaking,
          kind: isRequired
              ? ChangeKind.requiredFieldAdded
              : ChangeKind.optionalFieldAdded,
          typeName: type.name,
          fieldName: field.name,
          detail: rendered,
        ));
        continue;
      }

      // Common field — compare rendered types.
      final oldRendered = SdlPrinter.renderType(oldField.type);
      final newRendered = SdlPrinter.renderType(field.type);
      if (oldRendered == newRendered) continue;

      final detail = "was '$oldRendered', now '$newRendered'";
      if (_stripNonNull(oldField.type) == _stripNonNull(field.type)) {
        // Same underlying type shape — only nullability moved.
        changes.add(SchemaChange(
          severity: ChangeSeverity.breaking,
          kind: ChangeKind.nullabilityChanged,
          typeName: type.name,
          fieldName: field.name,
          detail: detail,
        ));
      } else {
        // Base type (or nested wrapper) changed — always breaking.
        changes.add(SchemaChange(
          severity: ChangeSeverity.breaking,
          kind: ChangeKind.fieldTypeChanged,
          typeName: type.name,
          fieldName: field.name,
          detail: detail,
        ));
      }
    }
  }

  /// Renders a type reference with all NON_NULL markers stripped, so
  /// `Money!` and `Money` compare equal but `Money` and `Int` do not.
  static String _stripNonNull(GqlTypeRef ref) {
    switch (ref.kind) {
      case GqlTypeKind.nonNull:
        return _stripNonNull(ref.ofType!);
      case GqlTypeKind.list:
        return '[${_stripNonNull(ref.ofType!)}]';
      default:
        return ref.name ?? 'Unknown';
    }
  }
}
