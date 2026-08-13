// entity_type_validator.dart
//
// Validates that every custom (non-primitive) field type referenced by an
// entity's fields resolves to either an existing entity directory or an
// existing enum file on disk — BEFORE the entity is written.
//
// Background (issue #296): when `zfa entity create` was called with a field
// type whose target did not yet exist on disk (e.g. `type:FeedbackType`
// before `zfa entity enum -n FeedbackType` was run), the zorphy
// `FieldNormalizer` silently assumed the type was an entity and prefixed it
// with `$`, producing `$FeedbackType`. Because `$FeedbackType` was
// undefined, the Dart analyzer resolved it to `InvalidType`, and the
// `ImportResolver` emitted a bogus entity-style import
// (`import '../feedback_type/feedback_type.dart';` for a directory that did
// not exist). The entity was written successfully (exit 0), and the failure
// only surfaced later at `zfa build` time as a misleading
// `json_serializable` error pointing at `InvalidType`.
//
// This validator closes that gap: it is invoked by `zfa entity create` and
// `zfa entity add-field` BEFORE any file is written. If any field type
// cannot be resolved, the command aborts with a clear, actionable error
// and a non-zero exit code, and no entity file is written.

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:zorphy/zorphy.dart' show FieldDefinition;
import 'entity_utils.dart';
import 'string_utils.dart';

/// A single validation failure: the unresolved type, the field that
/// referenced it, and a human-readable error message.
class UnresolvedTypeError {
  /// The field name that referenced the unresolved type (e.g. `type`).
  final String fieldName;

  /// The unresolved type as written by the user (e.g. `FeedbackType`,
  /// `$FeedbackType`, `List<FeedbackType>`). For generic types, this is
  /// the inner type that could not be resolved, not the full generic.
  final String typeName;

  /// A human-readable error message with an actionable fix.
  final String message;

  const UnresolvedTypeError({
    required this.fieldName,
    required this.typeName,
    required this.message,
  });

  @override
  String toString() => message;
}

/// Validates field types for an entity being created or modified.
///
/// A field type is considered **resolvable** when, after stripping
/// nullability (`?`), generic wrappers (`List<...>`, `Map<...>`), and the
/// Zorphy entity prefix (`$`), it is either:
///
///   1. a primitive Dart type (`String`, `int`, `double`, `bool`,
///      `DateTime`, `Map`, `List`, `dynamic`, `Object`, ... — see
///      [EntityUtils.extractEntityTypes] for the full exclusion list), or
///   2. the entity being created itself (self-reference — its directory
///      may not exist yet at creation time), or
///   3. an existing entity directory at
///      `<outputDir>/<snake(type)>/<snake(type)>.dart`, or
///   4. an existing enum file at
///      `<outputDir>/enums/<snake(type)>.dart`.
///
/// Anything else is unresolvable and produces an [UnresolvedTypeError].
class EntityTypeValidator {
  /// Validates [fields] against the on-disk entity/enum layout rooted at
  /// [outputDir].
  ///
  /// [selfEntityName] is the name of the entity being created (or the
  /// entity being modified by `add-field`); references to it are allowed
  /// even when its own directory does not exist yet.
  ///
  /// Returns a list of [UnresolvedTypeError] — one per unique unresolved
  /// type reference. An empty list means every field type is resolvable.
  static List<UnresolvedTypeError> validate({
    required List<FieldDefinition> fields,
    required String outputDir,
    String? selfEntityName,
  }) {
    final errors = <UnresolvedTypeError>[];
    // De-duplicate by (fieldName, typeName) so a type referenced by
    // multiple fields still produces one error per field, but a type
    // referenced multiple times by the SAME field (e.g. via nested
    // generics) only produces one.
    final seen = <String>{};

    for (final field in fields) {
      final referencedTypes = EntityUtils.extractEntityTypes(field.fullType);
      for (final type in referencedTypes) {
        // Strip a leading `$` (Zorphy entity prefix) — the user may write
        // either `FeedbackType` or `$FeedbackType`.
        final cleanType = type.replaceAll(RegExp(r'^\$+'), '');

        // Allow self-reference (the entity being created).
        if (cleanType == selfEntityName) continue;

        final key = '${field.name}::$cleanType';
        if (seen.contains(key)) continue;
        seen.add(key);

        final typeSnake = StringUtils.camelToSnake(cleanType);
        final entityDir = Directory(p.join(outputDir, typeSnake));
        final enumFile = File(p.join(outputDir, 'enums', '$typeSnake.dart'));

        final entityExists = entityDir.existsSync() &&
            File(p.join(entityDir.path, '$typeSnake.dart')).existsSync();
        final enumExists = enumFile.existsSync();

        if (!entityExists && !enumExists) {
          errors.add(UnresolvedTypeError(
            fieldName: field.name,
            typeName: cleanType,
            message:
                'Unknown type "$cleanType" for field "${field.name}" — no '
                'matching entity directory or enum file found under '
                '$outputDir.\n'
                '   Create the enum/entity first, for example:\n'
                '     zfa entity enum -n $cleanType --value <values>\n'
                '   or check the spelling.',
          ));
        }
      }
    }

    return errors;
  }

  /// Convenience wrapper that returns `true` when every field type is
  /// resolvable. Useful for guard clauses.
  static bool isValid({
    required List<FieldDefinition> fields,
    required String outputDir,
    String? selfEntityName,
  }) {
    return validate(
      fields: fields,
      outputDir: outputDir,
      selfEntityName: selfEntityName,
    ).isEmpty;
  }
}
