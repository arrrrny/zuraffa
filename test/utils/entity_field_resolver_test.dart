// Tests for EntityFieldResolver (#294 Gap 1, updated for #321).
//
// Covers:
//   - the id-resolution branches: literal `id`, first ending in `Id`,
//     `@Zorphy(autoId: true)` marker → synthetic id: String
//   - #321: NO silent first-field fallback — returns null when no id-like
//     field and no autoId marker (caller errors loudly)
//   - null when the entity file does not exist
//   - null when the entity file has no parseable field declarations
//   - nullable types are stripped from the returned type via `nonNullableType`
//   - parser handles both Zorphy `Type get fieldName;` form and the
//     hand-written `final Type fieldName;` form
//   - parser is case-sensitive for the field-name token and tolerant of
//     block comments
//   - parseEntityFieldsForEntity: distinguishes "file not found" (null)
//     from "file found, has fields" (non-empty list)

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/utils/entity_field_resolver.dart';

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
      expect(resolved!.name, 'id');
      expect(resolved.type, 'String');
      expect(resolved.nonNullableType, 'String');
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
        expect(resolved!.name, 'depotId');
        expect(resolved.type, 'String');
      },
    );

    test('#321 — returns null when there is no `id`, no `*Id` field, and no '
        'autoId marker (NO silent first-field fallback)', () async {
      // Issue #321 repro: an entity like ChatMessage whose first field is
      // an enum (role: ChatMessageRole) must NOT silently pick that field
      // as the id — that's what produced enum-typed ids (UpdateParams<
      // ChatMessageRole, ...>) without enum imports (issue #307). The
      // resolver returns null so the caller (MakeCommand) errors loudly.
      await writeEntity('GroceryPriceResult', '''
abstract class \$GroceryPriceResult {
  String get storeName;
  double get price;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'GroceryPriceResult',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNull);
    });

    test('#321 — returns null for the exact #307 repro shape (ChatMessage '
        'with enum first field, no id)', () async {
      // Direct repro from issue #307: ChatMessage has fields
      // role: ChatMessageRole / content: String / timestamp: DateTime —
      // no id, no *Id, no autoId. The resolver must return null so the
      // caller errors loudly instead of producing enum-typed ids.
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
      expect(resolved, isNull);
    });

    test('#321/#320 — `@Zorphy(autoId: true)` marker returns synthetic '
        '`id: String` field (forward-compatible with #320 autoId framework)',
        () async {
      // When #320 lands, entities annotated with @Zorphy(autoId: true)
      // get a uuid-populated id at runtime. For code generation, the
      // resolver returns a synthetic id: String so generated signatures
      // use String as the id type (no enum imports, no first-field
      // fallback, no loud error).
      await writeEntity('ChatMessage', '''
@Zorphy(autoId: true, json: true, copyWith: true)
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
      expect(resolved!.name, 'id');
      expect(resolved.type, 'String');
      expect(resolved.nonNullableType, 'String');
      // Same instance as the public autoIdField constant.
      expect(identical(resolved, EntityFieldResolver.autoIdField), isTrue);
    });

    test('#321/#320 — autoId marker wins over first-field fallback even when '
        'the first field is an enum (the #307 trigger)', () async {
      await writeEntity('TelemetryEvent', '''
@Zorphy(
  autoId: true,
  json: true,
)
abstract class \$TelemetryEvent {
  TelemetryEventType get type;
  DateTime get timestamp;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'TelemetryEvent',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNotNull);
      expect(resolved!.name, 'id');
      expect(resolved.type, 'String');
    });

    test('#321/#320 — autoId: false is treated the same as no marker '
        '(does NOT trigger the synthetic id)', () async {
      await writeEntity('ExplicitNoAutoId', '''
@Zorphy(autoId: false)
abstract class \$ExplicitNoAutoId {
  String get label;
  int get count;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'ExplicitNoAutoId',
        projectRoot: tempRoot.path,
      );
      // autoId: false is NOT true → no synthetic id, no id-like field → null.
      expect(resolved, isNull);
    });

    test('#321/#320 — autoId marker inside a block comment is ignored', () async {
      // A commented-out `@Zorphy(autoId: true)` must NOT match — the
      // resolver strips block comments before matching.
      await writeEntity('CommentedAutoId', '''
/*
@Zorphy(autoId: true)
*/
abstract class \$CommentedAutoId {
  String get label;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'CommentedAutoId',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNull);
    });

    test('#321/#320 — autoId marker inside a line comment is ignored', () async {
      await writeEntity('LineCommentedAutoId', '''
// @Zorphy(autoId: true)
abstract class \$LineCommentedAutoId {
  String get label;
}
''');
      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'LineCommentedAutoId',
        projectRoot: tempRoot.path,
      );
      expect(resolved, isNull);
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
        expect(resolved!.name, 'id');
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
      expect(resolved!.name, 'id');
      expect(resolved.type, 'int');
      expect(resolved.nonNullableType, 'int');
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
      expect(resolved!.name, 'maybeId');
      expect(resolved.type, 'String?');
      expect(resolved.nonNullableType, 'String');
    });

    test('handles Map<K, V> field types (parse + nonNullableType)', () async {
      // #321: the entity below has no `id`, no `*Id`, and no autoId marker.
      // The resolver returns null (NOT `metadata` — that's a Map, not an
      // id-like field). The parseEntityFields call below verifies the
      // parser still correctly extracts Map-typed fields and that
      // nonNullableType strips the trailing `?` cleanly, which is the
      // original purpose of this test.
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
      // #321: no id-like field, no autoId → null (NOT `metadata`).
      expect(resolved, isNull);

      // Verify the parser still handles Map<K, V> types correctly.
      final fields = EntityFieldResolver.parseEntityFieldsForEntity(
        entityName: 'WithMap',
        projectRoot: tempRoot.path,
      );
      expect(fields, isNotNull);
      expect(fields!.length, 2);
      expect(fields[0].name, 'metadata');
      expect(fields[0].type, contains('Map<String, dynamic>'));
      expect(fields[0].nonNullableType, 'Map<String, dynamic>');
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
      // Note: this entity has no `id` and no `*Id` field. Per #321, the
      // resolver returns null (no silent first-field fallback).
      // `slug` is NOT picked as the id — it has no `Id` suffix.
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
      // #321: no id-like field, no autoId marker → null (NOT `slug`).
      expect(resolved, isNull);
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
      expect(resolved!.name, 'realId');
    });

    test('respects an explicit `Id` suffix (not just `Id` literal)', () async {
      // `Id` itself (length 2) should NOT match branch 2 — too ambiguous.
      // Per #321: no other id-like field, no autoId marker → null
      // (NO silent first-field fallback to `Id`).
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
      // #321: `Id` (length 2) doesn't match branch 2; no other id-like
      // field; no autoId → null.
      expect(resolved, isNull);
    });
  });

  group('parseEntityFieldsForEntity (#321)', () {
    test('returns null when the entity file does not exist', () {
      final fields = EntityFieldResolver.parseEntityFieldsForEntity(
        entityName: 'NoSuchEntity',
        projectRoot: tempRoot.path,
      );
      expect(fields, isNull);
    });

    test('returns a non-empty list when the entity file exists and has '
        'fields (lets MakeCommand distinguish "file not found" from '
        '"file found, no id-like field" for the #321 loud-error path)', () async {
      await writeEntity('ChatMessage', '''
abstract class \$ChatMessage {
  ChatMessageRole get role;
  String get content;
  DateTime get timestamp;
}
''');
      final fields = EntityFieldResolver.parseEntityFieldsForEntity(
        entityName: 'ChatMessage',
        projectRoot: tempRoot.path,
      );
      expect(fields, isNotNull);
      expect(fields!.length, 3);
      expect(fields.map((f) => f.name).toList(),
          ['role', 'content', 'timestamp']);
    });

    test('returns an empty list when the entity file exists but has no '
        'parseable field declarations', () async {
      await writeEntity('Empty', '''
abstract class \$Empty {}
''');
      final fields = EntityFieldResolver.parseEntityFieldsForEntity(
        entityName: 'Empty',
        projectRoot: tempRoot.path,
      );
      expect(fields, isNotNull);
      expect(fields, isEmpty);
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
}

String _toSnake(String input) {
  if (input.isEmpty) return '';
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
  return result.join('');
}
