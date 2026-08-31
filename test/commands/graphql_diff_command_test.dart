@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/graphql/cache/schema_cache.dart';
import 'package:path/path.dart' as p;
import '../helpers/project_root.dart';

Map<String, dynamic> _fixture(String name) {
  final raw = File(p.join(_fixturesDir, 'graphql', name)).readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

late String _fixturesDir;

void main() {
  setUpAll(() async {
    _fixturesDir = p.join(await findProjectRoot(), 'test', 'fixtures');
  });

  late CliRunner runner;
  late Directory tempDir;
  late String cacheDir;
  late SchemaCache cache;

  setUp(() {
    runner = CliRunner(exitOnCompletion: false);
    tempDir = Directory.systemTemp.createTempSync('zfa_diff_cmd_');
    cacheDir = '${tempDir.path}/.zfa/graphql';
    cache = SchemaCache(cacheDir: cacheDir);
    exitCode = 0;
  });

  tearDown(() {
    exitCode = 0;
    tempDir.deleteSync(recursive: true);
  });

  group('zfa graphql diff (CLI)', () {
    test('breaking diff prints all changes and exits 1 (FR-004)', () async {
      await cache.write(
        'vendure',
        _fixture('vendure_shop_introspection_v1.json'),
      );
      await cache.write(
        'vendure',
        _fixture('vendure_shop_introspection_v2.json'),
      );

      final output = await runner.runCapturing([
        'graphql',
        'diff',
        'vendure',
        '--dir=$cacheDir',
      ]);

      // Breaking changes reported with type.field detail.
      expect(output, contains('Collection'));
      expect(output, contains('Product.description'));
      expect(output, contains('ProductVariant.price'));
      expect(output, contains('Order.code'));
      expect(output, contains('NATURAL'));
      // Non-breaking changes reported too.
      expect(output, contains('Product.slug'));
      expect(output, contains('XBT'));
      expect(output, contains('SearchResponse'));
      // Breaking/non-breaking classification shown.
      expect(output.toLowerCase(), contains('breaking'));
      // Exit code 1 because breaking changes exist.
      expect(exitCode, 1);
    });

    test('clean diff reports no changes and exits 0', () async {
      await cache.write(
        'vendure',
        _fixture('vendure_shop_introspection_v1.json'),
      );
      await cache.write(
        'vendure',
        _fixture('vendure_shop_introspection_v1.json'),
      );

      final output = await runner.runCapturing([
        'graphql',
        'diff',
        'vendure',
        '--dir=$cacheDir',
      ]);
      expect(output.toLowerCase(), contains('no breaking'));
      expect(exitCode, 0);
    });

    test('--old/--new explicit files override the cache', () async {
      final oldFile = File('${tempDir.path}/old.json')
        ..writeAsStringSync(
          jsonEncode(_fixture('vendure_shop_introspection_v1.json')),
        );
      final newFile = File('${tempDir.path}/new.json')
        ..writeAsStringSync(
          jsonEncode(_fixture('vendure_shop_introspection_v2.json')),
        );

      final output = await runner.runCapturing([
        'graphql',
        'diff',
        'vendure',
        '--old=${oldFile.path}',
        '--new=${newFile.path}',
      ]);
      expect(output, contains('Product.description'));
      expect(exitCode, 1);
    });

    test('unknown name lists cached schemas and errors', () async {
      await cache.write(
        'vendure',
        _fixture('vendure_shop_introspection_v1.json'),
      );

      final output = await runner.runCapturing([
        'graphql',
        'diff',
        'ghost',
        '--dir=$cacheDir',
      ]);
      expect(output.toLowerCase(), contains('error'));
      expect(output, contains('vendure'));
      expect(exitCode, isNot(0));
    });

    test('no previous version suggests a first pull', () async {
      await cache.write(
        'vendure',
        _fixture('vendure_shop_introspection_v1.json'),
      );

      final output = await runner.runCapturing([
        'graphql',
        'diff',
        'vendure',
        '--dir=$cacheDir',
      ]);
      expect(output.toLowerCase(), contains('pull'));
      expect(exitCode, isNot(0));
    });
  });
}
