// Tests for EntityFieldResolver (#294 Gap 1).
//
// Covers:
//   - the three id-resolution branches (literal `id`, first ending in `Id`,
//     first declared field)
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

    test('branch 3 — falls back to the first declared field when there is no '
        '`id` and no `*Id` field', () async {
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
      expect(resolved, isNotNull);
      expect(resolved!.name, 'storeName');
      expect(resolved.type, 'String');
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
      expect(resolved!.name, 'metadata');
      expect(resolved.type, contains('Map<String, dynamic>'));
      // nonNullableType strips the trailing `?` if present, but leaves
      // the rest of the type intact.
      expect(resolved.nonNullableType, 'Map<String, dynamic>');
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
      expect(resolved, isNotNull);
      expect(resolved!.name, 'slug');
      expect(resolved.type, 'String');
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
      // Fall through to branch 3 (first field).
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
      expect(resolved!.name, 'Id'); // first declared field, branch 3
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
