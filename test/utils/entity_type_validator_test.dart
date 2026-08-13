// Unit tests for EntityTypeValidator (issue #296).
//
// The validator is invoked by `zfa entity create` and `zfa entity add-field`
// BEFORE any file is written. It refuses to let the command proceed when a
// field type is neither a primitive, an existing entity, nor an existing
// enum — closing the gap where zorphy's FieldNormalizer silently `$`-prefixed
// unresolvable types, producing `InvalidType` + a bogus entity-style import.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zorphy/zorphy.dart' show FieldDefinition;
import 'package:zuraffa/src/utils/entity_type_validator.dart';

void main() {
  late Directory tmp;
  late String outputDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('entity_type_validator_');
    outputDir = p.join(tmp.path, 'lib', 'src', 'domain', 'entities');
    await Directory(outputDir).create(recursive: true);
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  /// Creates an entity directory + file so the validator recognises the type.
  Future<void> writeEntity(String name) async {
    final snake = _toSnake(name);
    final dir = Directory(p.join(outputDir, snake));
    await dir.create(recursive: true);
    await File(
      p.join(dir.path, '$snake.dart'),
    ).writeAsString('abstract class \$$name {}\n');
  }

  /// Creates an enum file under `enums/` so the validator recognises the type.
  Future<void> writeEnum(String name) async {
    final snake = _toSnake(name);
    final enumsDir = Directory(p.join(outputDir, 'enums'));
    await enumsDir.create(recursive: true);
    await File(
      p.join(enumsDir.path, '$snake.dart'),
    ).writeAsString('enum $name { a, b, c }\n');
  }

  group('EntityTypeValidator.validate — primitives', () {
    test('accepts all primitive field types with no entity/enum on disk', () {
      final fields = [
        FieldDefinition(name: 'id', type: 'String', nullable: true),
        FieldDefinition(name: 'count', type: 'int'),
        FieldDefinition(name: 'price', type: 'double'),
        FieldDefinition(name: 'active', type: 'bool'),
        FieldDefinition(name: 'createdAt', type: 'DateTime', nullable: true),
        FieldDefinition(name: 'meta', type: 'Map<String, dynamic>'),
        FieldDefinition(name: 'tags', type: 'List<String>'),
        FieldDefinition(name: 'dynamic', type: 'dynamic'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty, reason: 'Primitives must always resolve');
    });

    test('accepts Duration, Uri, BigInt, Uint8List as built-in types', () {
      final fields = [
        FieldDefinition(name: 'timeout', type: 'Duration'),
        FieldDefinition(name: 'link', type: 'Uri', nullable: true),
        FieldDefinition(name: 'largeNumber', type: 'BigInt'),
        FieldDefinition(name: 'bytes', type: 'Uint8List'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty,
          reason: 'Duration, Uri, BigInt, Uint8List are built-in Dart types');
    });

    test('accepts List<Duration> and other collections of built-in types', () {
      final fields = [
        FieldDefinition(name: 'durations', type: 'List<Duration>'),
        FieldDefinition(name: 'uris', type: 'List<Uri>'),
        FieldDefinition(name: 'numbers', type: 'List<BigInt>'),
        FieldDefinition(name: 'byteArrays', type: 'Map<String, Uint8List>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty,
          reason: 'Collections of built-in types must resolve');
    });
  });

  group('EntityTypeValidator.validate — existing entity', () {
    test('accepts a field type whose entity directory exists', () async {
      await writeEntity('Product');
      final fields = [FieldDefinition(name: 'product', type: 'Product')];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty);
    });

    test('accepts a nullable entity reference', () async {
      await writeEntity('Product');
      final fields = [
        FieldDefinition(name: 'product', type: 'Product', nullable: true),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty);
    });

    test('accepts List<EntityType> when the entity exists', () async {
      await writeEntity('Product');
      final fields = [FieldDefinition(name: 'items', type: 'List<Product>')];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty);
    });

    test('accepts Map<String, EntityType> when the entity exists', () async {
      await writeEntity('Product');
      final fields = [
        FieldDefinition(name: 'byKey', type: 'Map<String, Product>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty);
    });

    test('accepts nested List<List<EntityType>> when the entity exists', () async {
      await writeEntity('Product');
      final fields = [
        FieldDefinition(name: 'matrix', type: 'List<List<Product>>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty,
          reason: 'Nested generics should recursively extract the entity type');
    });

    test('accepts Map<String, List<EntityType>> when the entity exists', () async {
      await writeEntity('Product');
      final fields = [
        FieldDefinition(name: 'grouped', type: 'Map<String, List<Product>>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty,
          reason: 'Nested Map-List combinations should extract the entity type');
    });

    test('accepts List<Map<String, EntityType>> when the entity exists', () async {
      await writeEntity('Product');
      final fields = [
        FieldDefinition(name: 'items', type: 'List<Map<String, Product>>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty,
          reason: 'Nested List-Map combinations should extract the entity type');
    });

    test('accepts Set<EntityType> when the entity exists', () async {
      await writeEntity('Product');
      final fields = [
        FieldDefinition(name: 'uniqueItems', type: 'Set<Product>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty);
    });
  });

  group('EntityTypeValidator.validate — nested generics (#296 review)', () {
    test(
      'accepts Map<String, List<EntityType>> when the entity exists',
      () async {
        await writeEntity('Product');
        final fields = [
          FieldDefinition(name: 'byKey', type: 'Map<String, List<Product>>'),
        ];
        final errors = EntityTypeValidator.validate(
          fields: fields,
          outputDir: outputDir,
        );
        expect(
          errors,
          isEmpty,
          reason: 'Nested generic wrappers must not be treated as types',
        );
      },
    );

    test('accepts List<List<EntityType>> when the entity exists', () async {
      await writeEntity('Product');
      final fields = [
        FieldDefinition(name: 'matrix', type: 'List<List<Product>>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty);
    });

    test('accepts Iterable<EntityType> when the entity exists', () async {
      await writeEntity('Product');
      final fields = [
        FieldDefinition(name: 'items', type: 'Iterable<Product>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty);
    });

    test(
      'accepts List<Map<String, EntityType>> when the entity exists',
      () async {
        await writeEntity('Product');
        final fields = [
          FieldDefinition(name: 'matrix', type: 'List<Map<String, Product>>'),
        ];
        final errors = EntityTypeValidator.validate(
          fields: fields,
          outputDir: outputDir,
        );
        expect(errors, isEmpty);
      },
    );

    test(
      'accepts pure-primitive nested collections with no entity/enum on disk',
      () {
        final fields = [
          FieldDefinition(name: 'meta', type: 'List<Map<String, dynamic>>'),
          FieldDefinition(name: 'tags', type: 'Set<String>'),
          FieldDefinition(name: 'lookup', type: 'Map<String, List<String>>'),
        ];
        final errors = EntityTypeValidator.validate(
          fields: fields,
          outputDir: outputDir,
        );
        expect(
          errors,
          isEmpty,
          reason: 'Pure-primitive nested collections must resolve',
        );
      },
    );
  });

  group('EntityTypeValidator.validate — existing enum', () {
    test('accepts a field type whose enum file exists', () async {
      await writeEnum('FeedbackType');
      final fields = [FieldDefinition(name: 'type', type: 'FeedbackType')];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty);
    });

    test('accepts a nullable enum reference', () async {
      await writeEnum('FeedbackType');
      final fields = [
        FieldDefinition(name: 'type', type: 'FeedbackType', nullable: true),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, isEmpty);
    });
  });

  group('EntityTypeValidator.validate — unresolvable types (#296)', () {
    test('rejects a field type when neither entity nor enum exists', () {
      final fields = [FieldDefinition(name: 'type', type: 'FeedbackType')];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, hasLength(1));
      expect(errors.first.fieldName, 'type');
      expect(errors.first.typeName, 'FeedbackType');
      expect(errors.first.message, contains('Unknown type "FeedbackType"'));
      expect(errors.first.message, contains('zfa entity enum -n FeedbackType'));
    });

    test('rejects the EXACT issue #296 field set (FeedbackType missing)', () {
      // Mirror the issue report: Feedback created BEFORE FeedbackType enum.
      final fields = [
        FieldDefinition(name: 'id', type: 'String', nullable: true),
        FieldDefinition(name: 'message', type: 'String'),
        FieldDefinition(name: 'type', type: 'FeedbackType'),
        FieldDefinition(name: 'imageUrl', type: 'String', nullable: true),
        FieldDefinition(name: 'createdAt', type: 'DateTime', nullable: true),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
        selfEntityName: 'Feedback',
      );
      expect(errors, hasLength(1));
      expect(errors.first.fieldName, 'type');
      expect(errors.first.typeName, 'FeedbackType');
    });

    test('rejects a dollar-prefixed unresolvable type (user wrote \$Foo)', () {
      final fields = [FieldDefinition(name: 'ref', type: r'$Foo')];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, hasLength(1));
      // The `$` is stripped in the reported type name.
      expect(errors.first.typeName, 'Foo');
    });

    test('rejects List<Unresolvable>', () {
      final fields = [
        FieldDefinition(name: 'items', type: 'List<Unresolvable>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, hasLength(1));
      expect(errors.first.typeName, 'Unresolvable');
      expect(errors.first.fieldName, 'items');
    });

    test('rejects Map<String, Unresolvable>', () {
      final fields = [
        FieldDefinition(name: 'byKey', type: 'Map<String, Unresolvable>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, hasLength(1));
      expect(errors.first.typeName, 'Unresolvable');
    });

    test('rejects nested List<List<Unresolvable>>', () {
      final fields = [
        FieldDefinition(name: 'matrix', type: 'List<List<Unresolvable>>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, hasLength(1));
      expect(errors.first.typeName, 'Unresolvable',
          reason: 'Nested generics should recursively detect unresolvable types');
    });

    test('rejects nested Map<String, List<Unresolvable>>', () {
      final fields = [
        FieldDefinition(name: 'grouped', type: 'Map<String, List<Unresolvable>>'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, hasLength(1));
      expect(errors.first.typeName, 'Unresolvable');
    });

    test('collects one error per unresolvable field (multiple bad fields)', () {
      final fields = [
        FieldDefinition(name: 'a', type: 'MissingA'),
        FieldDefinition(name: 'b', type: 'MissingB'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors, hasLength(2));
      final names = errors.map((e) => e.typeName).toSet();
      expect(names, containsAll(<String>['MissingA', 'MissingB']));
    });

    test('de-duplicates the same type referenced by multiple fields', () {
      final fields = [
        FieldDefinition(name: 'a', type: 'Missing'),
        FieldDefinition(name: 'b', type: 'Missing'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      // One error PER FIELD (a, b) — de-dup is per (field, type) pair.
      expect(errors, hasLength(2));
      final fieldNames = errors.map((e) => e.fieldName).toSet();
      expect(fieldNames, containsAll(<String>['a', 'b']));
    });

    test('the error message names the outputDir and the field', () {
      final fields = [FieldDefinition(name: 'status', type: 'StatusEnum')];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
      );
      expect(errors.first.message, contains(outputDir));
      expect(errors.first.message, contains('status'));
    });
  });

  group(
    'EntityTypeValidator.validate — unsupported Dart types (#296 review)',
    () {
      // zorphy's FieldNormalizer does NOT treat these as primitives, so it
      // would `$`-prefix them (`$Duration`) and the build would fail with
      // InvalidType. The validator must reject them fail-fast, with a message
      // that does NOT suggest creating an enum for a standard Dart type.
      test(
        'rejects Duration with a "not supported" message (no enum hint)',
        () {
          final fields = [FieldDefinition(name: 'ttl', type: 'Duration')];
          final errors = EntityTypeValidator.validate(
            fields: fields,
            outputDir: outputDir,
          );
          expect(errors, hasLength(1));
          expect(errors.first.typeName, 'Duration');
          expect(
            errors.first.message,
            contains('not supported as a field type'),
          );
          expect(errors.first.message, isNot(contains('zfa entity enum')));
        },
      );

      test('rejects Uri, BigInt and Uint8List the same way', () {
        final fields = [
          FieldDefinition(name: 'link', type: 'Uri'),
          FieldDefinition(name: 'amount', type: 'BigInt'),
          FieldDefinition(name: 'bytes', type: 'Uint8List'),
        ];
        final errors = EntityTypeValidator.validate(
          fields: fields,
          outputDir: outputDir,
        );
        expect(errors, hasLength(3));
        for (final err in errors) {
          expect(err.message, contains('not supported as a field type'));
          expect(err.message, isNot(contains('zfa entity enum')));
        }
      });

      test('rejects List<Duration> with the "not supported" message', () {
        final fields = [
          FieldDefinition(name: 'durations', type: 'List<Duration>'),
        ];
        final errors = EntityTypeValidator.validate(
          fields: fields,
          outputDir: outputDir,
        );
        expect(errors, hasLength(1));
        expect(errors.first.typeName, 'Duration');
        expect(errors.first.message, contains('not supported as a field type'));
      });
    },
  );

  group('EntityTypeValidator.validate — self-reference', () {
    test('allows the entity being created to reference itself', () {
      final fields = [
        FieldDefinition(name: 'parent', type: 'Node', nullable: true),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
        selfEntityName: 'Node',
      );
      expect(
        errors,
        isEmpty,
        reason:
            'Self-reference is allowed even when the entity dir '
            'does not exist yet',
      );
    });

    test('allows List<Self> for the entity being created', () {
      final fields = [FieldDefinition(name: 'children', type: 'List<Node>')];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
        selfEntityName: 'Node',
      );
      expect(errors, isEmpty);
    });

    test('does NOT allow a DIFFERENT unresolvable type alongside self-ref', () {
      final fields = [
        FieldDefinition(name: 'parent', type: 'Node', nullable: true),
        FieldDefinition(name: 'kind', type: 'MissingKind'),
      ];
      final errors = EntityTypeValidator.validate(
        fields: fields,
        outputDir: outputDir,
        selfEntityName: 'Node',
      );
      expect(errors, hasLength(1));
      expect(errors.first.typeName, 'MissingKind');
    });
  });

  group('EntityTypeValidator.isValid', () {
    test('returns true when validate returns no errors', () async {
      await writeEnum('Status');
      final ok = EntityTypeValidator.isValid(
        fields: [FieldDefinition(name: 's', type: 'Status')],
        outputDir: outputDir,
      );
      expect(ok, isTrue);
    });

    test('returns false when validate returns errors', () {
      final ok = EntityTypeValidator.isValid(
        fields: [FieldDefinition(name: 's', type: 'Missing')],
        outputDir: outputDir,
      );
      expect(ok, isFalse);
    });
  });

  group(
    'EntityTypeValidator.validate — entity dir exists but file missing',
    () {
      test(
        'rejects when the entity directory exists but the .dart file is absent',
        () async {
          // Simulate a half-written entity (dir created, file not yet).
          final dir = Directory(p.join(outputDir, 'ghost'));
          await dir.create(recursive: true);
          final fields = [FieldDefinition(name: 'g', type: 'Ghost')];
          final errors = EntityTypeValidator.validate(
            fields: fields,
            outputDir: outputDir,
          );
          expect(
            errors,
            hasLength(1),
            reason:
                'An entity directory without the .dart file is not a '
                'validatable entity — treat as unresolvable.',
          );
        },
      );
    },
  );
}

/// Minimal PascalCase -> snake_case (mirrors StringUtils.camelToSnake for
/// the common PascalCase inputs used in these tests).
String _toSnake(String input) {
  if (input.isEmpty) return '';
  final result = <String>[];
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (i > 0 &&
        char.toLowerCase() != char &&
        char.toUpperCase() == char &&
        char != '_') {
      result.add('_');
    }
    result.add(char.toLowerCase());
  }
  return result.join();
}
