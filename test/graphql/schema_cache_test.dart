import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('SchemaCache', () {
    late Directory tempDir;
    late SchemaCache cache;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('graphql_test_');
      cache = SchemaCache(cacheDir: tempDir.path);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('save and load from cache', () async {
      final json = {
        'data': {
          '__schema': {
            'queryType': {'name': 'Query'},
            'types': [
              {'kind': 'OBJECT', 'name': 'Query', 'fields': []},
              {'kind': 'SCALAR', 'name': 'String'},
            ],
          },
        },
      };

      await cache.save(json);
      expect(await cache.hasCache(), true);

      final schema = await cache.load();
      expect(schema.queryTypeName, 'Query');
      expect(schema.types.length, 2);
    });

    test('throws when no cache and no endpoint', () async {
      await expectLater(cache.load(), throwsA(isA<SchemaCacheError>()));
    });

    test('hasCache returns false when no file', () async {
      expect(await cache.hasCache(), false);
    });

    test('overwrites existing cache on save', () async {
      await cache.save({
        'data': {
          '__schema': {
            'queryType': {'name': 'Old'},
            'types': [],
          },
        },
      });

      await cache.save({
        'data': {
          '__schema': {
            'queryType': {'name': 'New'},
            'types': [],
          },
        },
      });

      final schema = await cache.load();
      expect(schema.queryTypeName, 'New');
    });
  });
}
