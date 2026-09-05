import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/graphql/diff/schema_diff.dart';
import 'package:zuraffa/src/graphql/graphql_schema.dart';
import 'package:path/path.dart' as p;

import '../helpers/project_root.dart';

GqlSchema _load(String file) {
  final raw = File(p.join(_fixturesDir, 'graphql', file)).readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return GqlSchema.fromIntrospection(json['data'] as Map<String, dynamic>);
}

late String _fixturesDir;

void main() {
  setUpAll(() async {
    _fixturesDir = p.join(await findProjectRoot(), 'test', 'fixtures');
  });

  late GqlSchema v1;
  late GqlSchema v2;

  setUp(() {
    v1 = _load('vendure_shop_introspection_v1.json');
    v2 = _load('vendure_shop_introspection_v2.json');
  });

  group('SchemaDiffer', () {
    test('identical schemas produce no changes', () {
      final diff = SchemaDiffer.diff(
        v1,
        _load('vendure_shop_introspection_v1.json'),
      );
      expect(diff.changes, isEmpty);
      expect(diff.hasBreaking, false);
    });

    test('removed type reported as breaking', () {
      final diff = SchemaDiffer.diff(v1, v2);
      final removed = diff.changes.where(
        (c) => c.kind == ChangeKind.typeRemoved,
      );
      expect(removed, hasLength(1));
      expect(removed.first.typeName, 'Collection');
      expect(removed.first.severity, ChangeSeverity.breaking);
    });

    test('removed field reported as breaking with type+field names', () {
      final diff = SchemaDiffer.diff(v1, v2);
      final removed = diff.changes.where(
        (c) => c.kind == ChangeKind.fieldRemoved,
      );
      expect(removed, hasLength(1));
      expect(removed.first.typeName, 'Product');
      expect(removed.first.fieldName, 'description');
      expect(removed.first.severity, ChangeSeverity.breaking);
    });

    test('nullability change reported as breaking with old and new types', () {
      final diff = SchemaDiffer.diff(v1, v2);
      final changed = diff.changes.where(
        (c) => c.kind == ChangeKind.nullabilityChanged,
      );
      expect(changed, hasLength(1));
      final change = changed.first;
      expect(change.typeName, 'ProductVariant');
      expect(change.fieldName, 'price');
      expect(change.severity, ChangeSeverity.breaking);
      expect(change.detail, contains('Money!'));
      expect(change.detail, contains('Money'));
    });

    test('added required field reported as breaking', () {
      final diff = SchemaDiffer.diff(v1, v2);
      final added = diff.changes.where(
        (c) => c.kind == ChangeKind.requiredFieldAdded,
      );
      expect(added, hasLength(1));
      expect(added.first.typeName, 'Order');
      expect(added.first.fieldName, 'code');
      expect(added.first.severity, ChangeSeverity.breaking);
    });

    test('added optional field reported as non-breaking', () {
      final diff = SchemaDiffer.diff(v1, v2);
      final added = diff.changes.where(
        (c) => c.kind == ChangeKind.optionalFieldAdded,
      );
      // Product.slug and Query.search are both optional additions.
      expect(
        added.map((c) => '${c.typeName}.${c.fieldName}'),
        containsAll(['Product.slug', 'Query.search']),
      );
      for (final change in added) {
        expect(change.severity, ChangeSeverity.nonBreaking);
      }
    });

    test('added enum value reported as non-breaking', () {
      final diff = SchemaDiffer.diff(v1, v2);
      final added = diff.changes.where(
        (c) => c.kind == ChangeKind.enumValueAdded,
      );
      expect(added, hasLength(1));
      expect(added.first.typeName, 'CurrencyCode');
      expect(added.first.fieldName, 'XBT');
      expect(added.first.severity, ChangeSeverity.nonBreaking);
    });

    test('removed enum value reported as breaking', () {
      final diff = SchemaDiffer.diff(v1, v2);
      final removed = diff.changes.where(
        (c) => c.kind == ChangeKind.enumValueRemoved,
      );
      expect(removed, hasLength(1));
      expect(removed.first.typeName, 'SortOrder');
      expect(removed.first.fieldName, 'NATURAL');
      expect(removed.first.severity, ChangeSeverity.breaking);
    });

    test('added type reported as non-breaking', () {
      final diff = SchemaDiffer.diff(v1, v2);
      final added = diff.changes.where((c) => c.kind == ChangeKind.typeAdded);
      expect(added, hasLength(1));
      expect(added.first.typeName, 'SearchResponse');
      expect(added.first.severity, ChangeSeverity.nonBreaking);
    });

    test(
      'v1 -> v2 fixture diff is exactly the 9 expected changes (SC-002)',
      () {
        final diff = SchemaDiffer.diff(v1, v2);
        expect(diff.changes, hasLength(9));

        final breaking = diff.changes
            .where((c) => c.severity == ChangeSeverity.breaking)
            .toList();
        final nonBreaking = diff.changes
            .where((c) => c.severity == ChangeSeverity.nonBreaking)
            .toList();
        expect(breaking, hasLength(5));
        expect(nonBreaking, hasLength(4));
        expect(diff.hasBreaking, true);

        // Breaking set (exact).
        expect(
          breaking
              .map((c) => '${c.kind.name}:${c.typeName}.${c.fieldName ?? ''}')
              .toSet(),
          {
            'typeRemoved:Collection.',
            'fieldRemoved:Product.description',
            'nullabilityChanged:ProductVariant.price',
            'requiredFieldAdded:Order.code',
            'enumValueRemoved:SortOrder.NATURAL',
          },
        );

        // Non-breaking set (exact).
        expect(
          nonBreaking
              .map((c) => '${c.kind.name}:${c.typeName}.${c.fieldName ?? ''}')
              .toSet(),
          {
            'optionalFieldAdded:Product.slug',
            'optionalFieldAdded:Query.search',
            'enumValueAdded:CurrencyCode.XBT',
            'typeAdded:SearchResponse.',
          },
        );
      },
    );

    test('changes render human-readable descriptions', () {
      final diff = SchemaDiffer.diff(v1, v2);
      for (final change in diff.changes) {
        final text = change.describe();
        expect(text, isNotEmpty);
        expect(text, contains(change.typeName));
      }
      final removedField = diff.changes.firstWhere(
        (c) => c.kind == ChangeKind.fieldRemoved,
      );
      expect(removedField.describe(), contains('Product.description'));
    });

    test('base type change (not just nullability) is breaking', () {
      final oldSchema = GqlSchema.fromIntrospection({
        '__schema': {
          'queryType': {'name': 'Query'},
          'types': [
            {
              'kind': 'OBJECT',
              'name': 'Query',
              'fields': [
                {
                  'name': 'a',
                  'args': [],
                  'type': {
                    'kind': 'NON_NULL',
                    'ofType': {'kind': 'SCALAR', 'name': 'String'},
                  },
                },
              ],
            },
          ],
        },
      });
      final newSchema = GqlSchema.fromIntrospection({
        '__schema': {
          'queryType': {'name': 'Query'},
          'types': [
            {
              'kind': 'OBJECT',
              'name': 'Query',
              'fields': [
                {
                  'name': 'a',
                  'args': [],
                  'type': {
                    'kind': 'NON_NULL',
                    'ofType': {'kind': 'SCALAR', 'name': 'Int'},
                  },
                },
              ],
            },
          ],
        },
      });
      final diff = SchemaDiffer.diff(oldSchema, newSchema);
      expect(diff.hasBreaking, true);
      final changed = diff.changes
          .where((c) => c.kind == ChangeKind.fieldTypeChanged)
          .toList();
      expect(changed, hasLength(1));
      expect(changed.first.detail, contains('String!'));
      expect(changed.first.detail, contains('Int!'));
    });
  });
}
