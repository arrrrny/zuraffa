import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/graphql/cache/schema_cache.dart';
import 'package:zuraffa/src/graphql/introspection/introspection_client.dart';
import 'package:path/path.dart' as p;

import '../helpers/project_root.dart';

Map<String, dynamic> _fixture(String name) {
  final raw = File(p.join(_fixturesDir, 'graphql', name)).readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// Transport that serves a committed fixture regardless of the endpoint.
IntrospectionTransport _fixtureTransport(String fileName) =>
    (endpoint, headers, query) async =>
        IntrospectionHttpResponse(200, jsonEncode(_fixture(fileName)));

/// Transport that simulates an unreachable endpoint.
IntrospectionTransport _failingTransport() =>
    (endpoint, headers, query) async =>
        throw const SocketException('connection refused');

late String _fixturesDir;

void main() {
  setUpAll(() async {
    _fixturesDir = p.join(await findProjectRoot(), 'test', 'fixtures');
  });

  late Directory tempDir;
  late SchemaCache cache;
  late String cacheDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('zfa_graphql_cache_');
    cacheDir = '${tempDir.path}/.zfa/graphql';
    cache = SchemaCache(cacheDir: cacheDir);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('SchemaCache (spec 037 per-name layout)', () {
    test('pull writes json + sdl in dir and flat layouts', () async {
      final cached = await cache.pull(
        'vendure',
        endpoint: Uri.parse('https://api.test/graphql'),
        transport: _fixtureTransport('vendure_shop_introspection_v1.json'),
      );

      // Canonical per-name directory layout (FR-001).
      final dirJson = File('$cacheDir/vendure/vendure.schema.json');
      final dirSdl = File('$cacheDir/vendure/vendure.schema.graphql');
      // Flat compatibility layout (US-1 scenario 1 path notation).
      final flatJson = File('$cacheDir/vendure.schema.json');
      final flatSdl = File('$cacheDir/vendure.schema.graphql');

      expect(dirJson.existsSync(), true, reason: 'dir json missing');
      expect(dirSdl.existsSync(), true, reason: 'dir sdl missing');
      expect(flatJson.existsSync(), true, reason: 'flat json missing');
      expect(flatSdl.existsSync(), true, reason: 'flat sdl missing');

      // JSON artifact contains the introspection result.
      final json = jsonDecode(dirJson.readAsStringSync());
      expect(json, isA<Map<String, dynamic>>());
      expect(json['data']['__schema'], isNotNull);

      // SDL artifact contains recognizable type definitions.
      final sdl = dirSdl.readAsStringSync();
      expect(sdl, contains('type Query'));
      expect(sdl, contains('type Product implements Node'));
      expect(sdl, contains('enum SortOrder'));

      expect(cached.name, 'vendure');
      expect(cached.schema.queryTypeName, 'Query');
      expect(cached.schema.types.containsKey('Product'), true);
    });

    test('re-pull overwrites and rotates prev', () async {
      await cache.pull(
        'vendure',
        endpoint: Uri.parse('https://api.test/graphql'),
        transport: _fixtureTransport('vendure_shop_introspection_v1.json'),
      );
      final first = File(
        '$cacheDir/vendure/vendure.schema.json',
      ).readAsStringSync();

      await cache.pull(
        'vendure',
        endpoint: Uri.parse('https://api.test/graphql'),
        transport: _fixtureTransport('vendure_shop_introspection_v2.json'),
      );

      final second = File(
        '$cacheDir/vendure/vendure.schema.json',
      ).readAsStringSync();
      expect(second, isNot(equals(first)), reason: 'files were not refreshed');

      final prev = File('$cacheDir/vendure/vendure.schema.prev.json');
      expect(prev.existsSync(), true, reason: 'prev version not retained');
      expect(prev.readAsStringSync(), equals(first));

      // The previous version is loadable.
      final prevSchema = await cache.readPrevious('vendure');
      expect(prevSchema, isNotNull);
      // v1 contains Collection, v2 does not.
      expect(prevSchema!.schema.types.containsKey('Collection'), true);
      final current = await cache.read('vendure');
      expect(current.schema.types.containsKey('Collection'), false);
      expect(current.schema.types.containsKey('SearchResponse'), true);
    });

    test('load unknown name throws with path (no null-on-failure)', () async {
      await expectLater(
        cache.read('missing'),
        throwsA(
          isA<SchemaCacheError>().having(
            (e) => e.message,
            'message',
            allOf(contains('missing'), contains('schema.json')),
          ),
        ),
      );
    });

    test('cache dir auto-created when missing', () async {
      expect(Directory(cacheDir).existsSync(), false);
      await cache.pull(
        'vendure',
        endpoint: Uri.parse('https://api.test/graphql'),
        transport: _fixtureTransport('vendure_shop_introspection_v1.json'),
      );
      expect(Directory(cacheDir).existsSync(), true);
      expect(File('$cacheDir/vendure.schema.json').existsSync(), true);
    });

    test('loadPrevious returns null when no previous version exists', () async {
      await cache.pull(
        'vendure',
        endpoint: Uri.parse('https://api.test/graphql'),
        transport: _fixtureTransport('vendure_shop_introspection_v1.json'),
      );
      expect(await cache.readPrevious('vendure'), isNull);
    });

    test('no partial files when fetch fails', () async {
      await expectLater(
        cache.pull(
          'vendure',
          endpoint: Uri.parse('https://api.test/graphql'),
          transport: _failingTransport(),
        ),
        throwsA(isA<IntrospectionException>()),
      );
      expect(File('$cacheDir/vendure.schema.json').existsSync(), false);
      expect(File('$cacheDir/vendure.schema.graphql').existsSync(), false);
      expect(File('$cacheDir/vendure/vendure.schema.json').existsSync(), false);
      expect(
        File('$cacheDir/vendure/vendure.schema.graphql').existsSync(),
        false,
      );
    });

    test('no partial files when schema is malformed', () async {
      await expectLater(
        cache.pull(
          'vendure',
          endpoint: Uri.parse('https://api.test/graphql'),
          transport: (endpoint, headers, query) async =>
              IntrospectionHttpResponse(200, jsonEncode({'data': {}})),
        ),
        throwsA(isA<IntrospectionException>()),
      );
      expect(File('$cacheDir/vendure.schema.json').existsSync(), false);
    });

    test('pull requires endpoint or transport', () async {
      await expectLater(
        cache.pull('vendure'),
        throwsA(isA<SchemaCacheError>()),
      );
    });

    test('write() persists json + sdl and rotates prev', () async {
      final v1 = _fixture('vendure_shop_introspection_v1.json');
      final v2 = _fixture('vendure_shop_introspection_v2.json');
      await cache.write('vendure', v1);
      await cache.write('vendure', v2);
      expect(File('$cacheDir/vendure/vendure.schema.json').existsSync(), true);
      expect(
        File('$cacheDir/vendure/vendure.schema.graphql').existsSync(),
        true,
      );
      expect(
        File('$cacheDir/vendure/vendure.schema.prev.json').existsSync(),
        true,
      );
      final current = await cache.read('vendure');
      expect(current.schema.types.containsKey('SearchResponse'), true);
    });

    test('hasSchema reports cached names', () async {
      expect(await cache.hasSchema('vendure'), false);
      await cache.write(
        'vendure',
        _fixture('vendure_shop_introspection_v1.json'),
      );
      expect(await cache.hasSchema('vendure'), true);
      expect(await cache.hasSchema('other'), false);
    });

    test('malformed cached json surfaces a clear error on load', () async {
      final dir = Directory('$cacheDir/vendure')..createSync(recursive: true);
      File(
        '$cacheDir/vendure/vendure.schema.json',
      ).writeAsStringSync('not json at all');
      expect(dir.existsSync(), true);
      await expectLater(
        cache.read('vendure'),
        throwsA(
          isA<SchemaCacheError>().having(
            (e) => e.message,
            'message',
            anyOf(contains('JSON'), contains('corrupt'), contains('parse')),
          ),
        ),
      );
    });
  });
}
