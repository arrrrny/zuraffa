// Tests for EntityFieldResolver (#294 Gap 1, #307 identity contract).
//
// Covers:
//   - the id-resolution branches (literal `id`, first ending in `Id`,
//     synthetic `id: String` for `autoId: true`)
//   - the #307 behavior: NO silent first-field fallback — an entity with
//     no id-like field and no autoId resolves with a null idField so the
//     caller (`zfa make`) fails loudly
//   - value objects (`@ZValueObject` / `kind: ZorphyKind.valueObject`)
//     resolve with no id at all
//   - null when the entity file does not exist
//   - null when the entity file has no parseable field declarations
//   - nullable types are stripped from the returned type via `nonNullableType`
//   - parser handles both Zorphy `Type get fieldName;` form and the
//     hand-written `final Type fieldName;` form
//   - parser is case-sensitive for the field-name token and tolerant of
//     block comments

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/utils/entity_field_resolver.dart';
import 'package:zuraffa/src/utils/string_utils.dart';

void main() {
  late Directory tempRoot;
  late String entitiesDir;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('entity_field_resolver_');
    entitiesDir = p.join(tempRoot.path, 'lib', 'src', 'domain', 'entities');
    await Directory(entitiesDir).create(recursive: true);
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  /// Helper: write an entity file with [content] at the conventional path
  /// `<root>/lib/src/domain/entities/<snake>/<snake>.dart`.
  Future<void> writeEntity(String name, String content) async {
    final snake = _toSnake(name);
    final dir = Directory(p.join(entitiesDir, snake));
    await dir.create(recursive: true);
    await File(p.join(dir.path, '$snake.dart')).writeAsString(content);
  }

  group('resolveIdField', () {
    test('returns null when the entity file does not exist', () {
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'NoSuchEntity',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNull);
    });

    test('branch 1 — picks the literal `id` field when present', () async {
      await writeEntity('Product', '''
abstract class \$Product {
  String get id;
  String get name;
  double get price;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'Product',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNotNull);
      expect(resolved!.kind, EntitySourceKind.entity);
      expect(resolved.autoId, isFalse);
      expect(resolved.hasId, isTrue);
      expect(resolved.idField!.name, 'id');
      expect(resolved.idField!.type, 'String');
      expect(resolved.idField!.nonNullableType, 'String');
    });

    test(
      'branch 2 — picks the first field ending in `Id` when there is no `id` '
      '(issue #294 repro: StorePrice uses depotId)',
      () async {
        await writeEntity('StorePrice', '''
abstract class \$StorePrice {
  String get depotId;
  String get storeName;
  double get price;
}
''');
        final resolved = EntityFieldResolver.resolveIdField(
          entityName: 'StorePrice',
          projectRoot: tempRoot.path,
        );
        expect(resolved, isNotNull);
        expect(resolved!.idField!.name, 'depotId');
        expect(resolved.idField!.type, 'String');
      },
    );

    test(
      '#307 — NO silent first-field fallback: an entity with no `id` and no '
      '`*Id` field resolves with a null idField (caller must fail loudly)',
      () async {
        // Exact #307 shape: first field is an enum-typed getter.
        await writeEntity('ChatMessage', '''
abstract class \$ChatMessage {
  ChatMessageRole get role;
  String get content;
  DateTime get timestamp;
}
''');
        final resolved = EntityFieldResolver.resolveIdField(
          entityName: 'ChatMessage',
          projectRoot: tempRoot.path,
        );
        expect(resolved, isNotNull);
        expect(resolved!.kind, EntitySourceKind.entity);
        expect(resolved.autoId, isFalse);
        expect(resolved.hasId, isFalse);
        expect(resolved.idField, isNull);
      },
    );

    test('autoId: true — resolves the synthetic id field as String even when '
        'the entity declares no id getter', () async {
      await writeEntity('TelemetryEvent', '''
import 'package:zorphy_annotation/zorphy_annotation.dart';

@Zorphy(generateJson: true, autoId: true)
abstract class \$TelemetryEvent {
  TelemetryEventType get type;
  String get value;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'TelemetryEvent',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNotNull);
      expect(resolved!.autoId, isTrue);
      expect(resolved.hasId, isTrue);
      expect(resolved.idField!.name, 'id');
      expect(resolved.idField!.type, 'String');
    });

    test(
      'autoId + explicit id getter — the real field wins, type preserved',
      () async {
        await writeEntity('AuthSession', '''
import 'package:zorphy_annotation/zorphy_annotation.dart';

@Zorphy(generateJson: true, autoId: true)
abstract class \$AuthSession {
  String get id;
  String get token;
}
''');
        final resolved = EntityFieldResolver.resolveIdField(
          entityName: 'AuthSession',
          projectRoot: tempRoot.path,
        );
        expect(resolved, isNotNull);
        expect(resolved!.autoId, isTrue);
        expect(resolved.idField!.name, 'id');
        expect(resolved.idField!.type, 'String');
      },
    );

    test('value object — no id resolved, kind is valueObject', () async {
      await writeEntity('ParserConfig', '''
import 'package:zorphy_annotation/zorphy_annotation.dart';

@ZValueObject
abstract class \$ParserConfig {
  String get separator;
  bool get trimWhitespace;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'ParserConfig',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNotNull);
      expect(resolved!.kind, EntitySourceKind.valueObject);
      expect(resolved.isValueObject, isTrue);
      expect(resolved.idField, isNull);
      expect(resolved.hasId, isFalse);
    });

    test('value object via @Zorphy(kind: ZorphyKind.valueObject)', () async {
      await writeEntity('MapTransformationOptions', '''
import 'package:zorphy_annotation/zorphy_annotation.dart';

@Zorphy(kind: ZorphyKind.valueObject, generateJson: true)
abstract class \$MapTransformationOptions {
  String get sourceKey;
  String get targetKey;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'MapTransformationOptions',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNotNull);
      expect(resolved!.isValueObject, isTrue);
      expect(resolved.idField, isNull);
    });

    test(
      'prefers literal `id` over an earlier `*Id` field when both exist',
      () async {
        await writeEntity('Audit', '''
abstract class \$Audit {
  String get tenantId;
  String get id;
  String get payload;
}
''');
        final resolved = EntityFieldResolver.resolveIdField(
          entityName: 'Audit',
          projectRoot: tempRoot.path,
        );
        expect(resolved, isNotNull);
        expect(resolved!.idField!.name, 'id');
      },
    );

    test('handles non-String id types (int)', () async {
      await writeEntity('Counter', '''
abstract class \$Counter {
  int get id;
  int get value;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'Counter',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNotNull);
      expect(resolved!.idField!.name, 'id');
      expect(resolved.idField!.type, 'int');
      expect(resolved.idField!.nonNullableType, 'int');
    });

    test('strips trailing `?` from nullable field types', () async {
      await writeEntity('SoftId', '''
abstract class \$SoftId {
  String? get maybeId;
  String get name;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'SoftId',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNotNull);
      expect(resolved!.idField!.name, 'maybeId');
      expect(resolved.idField!.type, 'String?');
      expect(resolved.idField!.nonNullableType, 'String');
    });

    test('handles Map<K, V> field types (parse + nonNullableType)', () async {
      await writeEntity('WithMap', '''
abstract class \$WithMap {
  Map<String, dynamic> get metadata;
  String get name;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'WithMap',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNotNull);
      // No id-like field: id-less entity, not a value object.
      expect(resolved!.kind, EntitySourceKind.entity);
      expect(resolved.hasId, isFalse);
    });

    test('returns null when entity file has no field declarations', () async {
      await writeEntity('Empty', '''
abstract class \$Empty {}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'Empty',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNull);
    });

    test('parses `final Type fieldName;` form (hand-written entity)', () async {
      await writeEntity('Handwritten', '''
class Handwritten {
  final String slug;
  final int count;
  const Handwritten({required this.slug, required this.count});
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'Handwritten',
        projectRoot: tempRoot.path,
      );
      // `slug` is not id-like → id-less entity (no silent fallback, #307).
      expect(resolved, isNotNull);
      expect(resolved!.kind, EntitySourceKind.entity);
      expect(resolved.hasId, isFalse);
    });

    test('ignores field-like text inside block comments', () async {
      await writeEntity('Commented', '''
abstract class \$Commented {
  /* was: String get id; */
  String get realId;
  String get name;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'Commented',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNotNull);
      expect(resolved!.idField!.name, 'realId');
    });

    test('respects an explicit `Id` suffix (not just `Id` literal)', () async {
      // `Id` itself (length 2) should NOT match branch 2 — too ambiguous.
      // With no `id` / `*Id` / autoId the entity is id-less (#307).
      await writeEntity('Ambiguous', '''
abstract class \$Ambiguous {
  String get Id;
  String get name;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'Ambiguous',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNotNull);
      expect(resolved!.kind, EntitySourceKind.entity);
      expect(resolved.hasId, isFalse);
      expect(resolved.idField, isNull);
    });
  });

  group('annotation detection', () {
    test('detectsAutoId only inside a Zorphy annotation arg list', () {
      expect(
        EntityFieldResolver.detectsAutoId('@Zorphy(autoId: true)'),
        isTrue,
      );
      expect(
        EntityFieldResolver.detectsAutoId(
          '@Zorphy(generateJson: true, autoId: true)',
        ),
        isTrue,
      );
      expect(
        EntityFieldResolver.detectsAutoId('@Zorphy(generateJson: true)'),
        isFalse,
      );
      expect(
        EntityFieldResolver.detectsAutoId('// autoId: true (comment)'),
        isFalse,
      );
    });

    test('detectsValueObject via @ZValueObject and kind:', () {
      expect(EntityFieldResolver.detectsValueObject('@ZValueObject'), isTrue);
      expect(
        EntityFieldResolver.detectsValueObject(
          '@Zorphy(kind: ZorphyKind.valueObject)',
        ),
        isTrue,
      );
      expect(
        EntityFieldResolver.detectsValueObject('@Zorphy(kind: valueObject)'),
        isTrue,
      );
      expect(
        EntityFieldResolver.detectsValueObject('@Zorphy(generateJson: true)'),
        isFalse,
      );
    });
  });

  group('parseEntityFields', () {
    test('returns an empty list for an empty file', () {
      expect(EntityFieldResolver.parseEntityFields(''), isEmpty);
    });

    test('returns fields in declaration order', () {
      final fields = EntityFieldResolver.parseEntityFields('''
abstract class \$Order {
  String get id;
  DateTime get placedAt;
  double get total;
}
''');
      expect(fields.map((f) => f.name).toList(), ['id', 'placedAt', 'total']);
      expect(fields[0].type, 'String');
      expect(fields[1].type, 'DateTime');
      expect(fields[2].type, 'double');
    });
  });

  // #508: id-neutral plugin paths (test/mock regeneration) still need a
  // query/filter key. It must be a representative REAL field — never an
  // enum-typed field (the pre-#307 first-field fallback bug), never a
  // synthetic id.
  group('issue #872 — resolver/writer snake_case conformance', () {
    // `zfa entity create -n <N>` lays the entity out at
    // `<entitiesDir>/<StringUtils.camelToSnake(N)>/<snake>.dart` (the
    // writer's naming). The resolver must find EXACTLY that layout for
    // every name the writer accepts — otherwise `zfa make <N>` fail-fasts
    // with #496 for an entity that exists on disk (bug #872, the
    // digit-after-capital family: A1 → a_1 vs a1).
    const names = ['Todo', 'TodoItem', 'A1', 'Node2', 'TodoItem2', 'SHA256'];

    for (final name in names) {
      test('entityFileExists finds what `entity create -n $name` writes',
          () async {
        // Lay the file down with the WRITER's own naming function — the
        // same one `zfa entity create` uses for its output path.
        final snake = StringUtils.camelToSnake(name);
        final dir = Directory(p.join(entitiesDir, snake));
        await dir.create(recursive: true);
        await File(
          p.join(dir.path, '$snake.dart'),
        ).writeAsString('abstract class \$$name {\n  String get id;\n}\n');

        final exists = EntityFieldResolver.entityFileExists(
          entityName: name,
          projectRoot: tempRoot.path,
        );
        expect(
          exists,
          isTrue,
          reason:
              'writer wrote "$snake/$snake.dart" but the resolver '
              'did not find it — its snake_case diverges '
              '(expected "$snake", got the old digit-underscored shape?)',
        );
      });
    }

    test('resolveIdField reads the digit-bearing entity the writer wrote',
        () async {
      final snake = StringUtils.camelToSnake('Node2');
      final dir = Directory(p.join(entitiesDir, snake));
      await dir.create(recursive: true);
      await File(
        p.join(dir.path, '$snake.dart'),
      ).writeAsString('abstract class \$Node2 {\n  String get id;\n}\n');

      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'Node2',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNotNull);
      expect(resolved!.idField, isNotNull);
      expect(resolved.idField!.name, 'id');
    });
  });

  group('resolveRepresentativeField (#508)', () {
    test(
      'skips an enum-typed first field and picks the first String',
      () async {
        await writeEntity('ChatMessage', '''
import 'package:zorphy_annotation/zorphy_annotation.dart';

@Zorphy(generateJson: true)
abstract class \$ChatMessage {
  ChatMessageRole get role;
  String get content;
  DateTime get timestamp;
}
''');
        final field = EntityFieldResolver.resolveRepresentativeField(
          entityName: 'ChatMessage',
          projectRoot: tempRoot.path,
        );
        expect(field, isNotNull);
        expect(field!.name, 'content');
        expect(field.type, 'String');
      },
    );

    test(
      'falls back to the first non-nullable int when no String exists',
      () async {
        await writeEntity('Counter', '''
abstract class \$Counter {
  CounterKind get kind;
  int get count;
  bool get active;
}
''');
        final field = EntityFieldResolver.resolveRepresentativeField(
          entityName: 'Counter',
          projectRoot: tempRoot.path,
        );
        expect(field, isNotNull);
        expect(field!.name, 'count');
        expect(field.nonNullableType, 'int');
      },
    );

    test('prefers non-nullable String over nullable String', () async {
      await writeEntity('Profile', '''
abstract class \$Profile {
  String? nickname;
  String get handle;
}
''');
      final field = EntityFieldResolver.resolveRepresentativeField(
        entityName: 'Profile',
        projectRoot: tempRoot.path,
      );
      expect(field, isNotNull);
      expect(field!.name, 'handle');
    });

    test('accepts a nullable String when only nullables exist', () async {
      await writeEntity('Lead', '''
abstract class \$Lead {
  LeadStatus get status;
  String? email;
}
''');
      final field = EntityFieldResolver.resolveRepresentativeField(
        entityName: 'Lead',
        projectRoot: tempRoot.path,
      );
      expect(field, isNotNull);
      expect(field!.name, 'email');
      expect(field.nonNullableType, 'String');
    });

    test(
      'falls back to other scalars (double/bool/DateTime) after String/int',
      () async {
        await writeEntity('Reading', '''
abstract class \$Reading {
  ReadingKind get kind;
  Map<String, dynamic> get meta;
  double get value;
}
''');
        final field = EntityFieldResolver.resolveRepresentativeField(
          entityName: 'Reading',
          projectRoot: tempRoot.path,
        );
        expect(field, isNotNull);
        expect(field!.name, 'value');
      },
    );

    test('never selects a List/Map field', () async {
      await writeEntity('Bucket', '''
abstract class \$Bucket {
  List<String> get items;
  Map<String, int> get counts;
}
''');
      final field = EntityFieldResolver.resolveRepresentativeField(
        entityName: 'Bucket',
        projectRoot: tempRoot.path,
      );
      expect(field, isNull);
    });

    test('returns null when only enum/custom-typed fields exist', () async {
      await writeEntity('Signal', '''
abstract class \$Signal {
  SignalType get type;
  ChatMessageRole get role;
}
''');
      final field = EntityFieldResolver.resolveRepresentativeField(
        entityName: 'Signal',
        projectRoot: tempRoot.path,
      );
      expect(field, isNull);
    });

    test('returns null when the entity file does not exist', () {
      final field = EntityFieldResolver.resolveRepresentativeField(
        entityName: 'NoSuchEntity',
        projectRoot: tempRoot.path,
      );
      expect(field, isNull);
    });
  });
}

// The fixture helper mirrors what `zfa entity create` actually writes:
// the writer's naming is StringUtils.camelToSnake (issue #872 conformance
// ground truth — NOT the resolver's old underscore-before-digit shape).
String _toSnake(String input) => StringUtils.camelToSnake(input);
