@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/cache/cache_verify.dart';

import '../../helpers/run_zfa_source.dart';

/// Spec #975, Order 3 — `zfa cache verify <Entity> [--json]` drift gate.
///
/// Reads the registrar + the entity graph, lists entities whose adapters
/// are missing or stale, exits 1 with one `--> fix:` line per finding, and
/// exits 0 only when every discovered entity is registered. Cache drift
/// becomes a CI gate.
///
/// Level 1 (in-process): the [CacheAdapterVerifier] service semantics.
/// Level 2 (subprocess): the real `zfa cache verify` CLI contract — exit
/// codes, text/JSON output, both drift directions of the acceptance
/// criteria.
void main() {
  group('CacheAdapterVerifier service (in-process)', () {
    late Directory workspace;
    late String outputDir;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('cache_verify_975_');
      outputDir = p.join(workspace.path, 'lib', 'src');
      for (final name in ['product', 'category', 'tag']) {
        final dir = p.join(outputDir, 'domain', 'entities', name);
        await Directory(dir).create(recursive: true);
      }
      await File(
        p.join(outputDir, 'domain', 'entities', 'tag', 'tag.dart'),
      ).writeAsString('class Tag { final String id; }\n');
      await File(
        p.join(outputDir, 'domain', 'entities', 'category', 'category.dart'),
      ).writeAsString('class Category { final Tag tag; }\n');
      await File(
        p.join(outputDir, 'domain', 'entities', 'product', 'product.dart'),
      ).writeAsString(
        'class Product { final String id; final Category category; }\n',
      );
    });

    tearDown(() async {
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    });

    CacheAdapterVerifier verifier() =>
        CacheAdapterVerifier(outputDir: outputDir, projectRoot: workspace.path);

    Future<void> writeRegistrar(String content) async {
      final cacheDir = p.join(outputDir, 'cache');
      await Directory(cacheDir).create(recursive: true);
      await File(
        p.join(cacheDir, 'hive_registrar.dart'),
      ).writeAsString(content);
    }

    test(
      'clean state: every discovered entity registered → ok, no findings',
      () async {
        await writeRegistrar('''
@GenerateAdapters([AdapterSpec<Product>(), AdapterSpec<Category>(), AdapterSpec<Tag>()])
extension HiveRegistrar on HiveInterface {}
''');

        final report = await verifier().verify('Product');

        expect(report.ok, isTrue);
        expect(report.findings, isEmpty);
        expect(
          report.expectedEntities,
          containsAll(['Product', 'Category', 'Tag']),
        );
        expect(
          report.registeredEntities,
          containsAll(['Product', 'Category', 'Tag']),
        );
      },
    );

    test('missing sub-entity adapter → finding with a --> fix line', () async {
      // Registrar registers Product but NOT its sub-entities.
      await writeRegistrar('''
@GenerateAdapters([AdapterSpec<Product>()])
extension HiveRegistrar on HiveInterface {}
''');

      final report = await verifier().verify('Product');

      expect(report.ok, isFalse);
      final missing = report.findings
          .where((f) => f.kind == 'missing')
          .map((f) => f.entity)
          .toSet();
      expect(missing, containsAll(['Category', 'Tag']));
      for (final finding in report.findings) {
        expect(finding.fix, contains('zfa cache adapter'));
        expect(
          finding.fix,
          contains(finding.entity),
          reason: 'the fix must name the missing adapter',
        );
      }
    });

    test('no registrar at all → every expected entity is missing', () async {
      final report = await verifier().verify('Product');

      expect(report.ok, isFalse);
      expect(
        report.findings.where((f) => f.kind == 'missing').map((f) => f.entity),
        containsAll(['Product', 'Category', 'Tag']),
      );
    });

    test('nonexistent entity → clear error naming the target', () async {
      expect(
        () => verifier().verify('Ghost'),
        throwsA(
          isA<CacheEntityNotFoundException>().having(
            (e) => e.message,
            'message',
            contains("Entity 'Ghost' not found"),
          ),
        ),
      );
    });

    test('JSON report round-trips through toJson()', () async {
      await writeRegistrar('''
@GenerateAdapters([AdapterSpec<Product>()])
extension HiveRegistrar on HiveInterface {}
''');

      final json = (await verifier().verify('Product')).toJson();
      expect(json['schema'], 'cache.verify.v1');
      expect(json['entity'], 'Product');
      expect(json['ok'], isFalse);
      expect(
        json['findings'],
        isA<List>().having((l) => l.length, 'count', greaterThanOrEqualTo(2)),
      );
    });
  });

  group('zfa cache verify CLI (subprocess)', () {
    setUpAll(initZfaSourceBin);

    late Directory workspace;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_cache_verify_');
      await Directory(
        p.join(workspace.path, 'lib', 'src'),
      ).create(recursive: true);
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_cache_verify_test
environment:
  sdk: ^3.11.0
''');
      for (final name in ['product', 'category']) {
        final dir = p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          name,
        );
        await Directory(dir).create(recursive: true);
      }
      await File(
        p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'category',
          'category.dart',
        ),
      ).writeAsString('class Category { final String id; }\n');
      await File(
        p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'product',
          'product.dart',
        ),
      ).writeAsString(
        'class Product { final String id; final Category category; }\n',
      );
    });

    tearDown(() {
      if (workspace.existsSync()) {
        try {
          workspace.deleteSync(recursive: true);
        } on PathNotFoundException {
          // Already gone.
        }
      }
    });

    Future<ProcessResult> runZfa(List<String> args) => runZfaSource([
      '-C',
      workspace.path,
      ...args,
    ], workingDirectory: workspace.path);

    test('no entity argument → usage error, exit 64', () async {
      final result = await runZfa(['cache', 'verify']);

      expect(result.exitCode, 64, reason: 'stdout=${result.stdout}');
      expect(result.stdout, contains('Usage'));
      expect(result.stdout, contains('zfa cache verify'));
    });

    test(
      'fresh adapter run → verify passes (both ways: the green side)',
      () async {
        final adapter = await runZfa(['cache', 'adapter', 'Product']);
        expect(
          adapter.exitCode,
          0,
          reason: 'stdout=${adapter.stdout} stderr=${adapter.stderr}',
        );

        final result = await runZfa(['cache', 'verify', 'Product']);

        expect(result.exitCode, 0, reason: 'stdout=${result.stdout}');
        expect(result.stdout, contains('verified'));
      },
    );

    test('stale adapter: entity graph grew after registration → exit 1 with '
        '--> fix per missing adapter (the red side)', () async {
      // Register Product while its graph is only Product itself.
      final productFile = File(
        p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'product',
          'product.dart',
        ),
      );
      await productFile.writeAsString('class Product { final String id; }\n');
      final adapter = await runZfa(['cache', 'adapter', 'Product']);
      expect(adapter.exitCode, 0, reason: 'stdout=${adapter.stdout}');

      // The entity now references a NEW sub-entity → the registration is
      // stale and Category's adapter is missing.
      await productFile.writeAsString(
        'class Product { final String id; final Category category; }\n',
      );

      final result = await runZfa(['cache', 'verify', 'Product']);

      expect(result.exitCode, 1, reason: 'stdout=${result.stdout}');
      expect(result.stdout, contains('Category'));
      expect(
        result.stdout,
        contains('--> fix: zfa cache adapter Category'),
        reason: 'one actionable fix line per missing adapter',
      );
      expect(
        result.stdout,
        isNot(contains('[missing] Product')),
        reason:
            'the target entity is stale, not missing — its adapter is '
            'registered but its registration is outdated',
      );
    });

    test('re-running the adapter heals the drift → verify passes (both '
        'ways)', () async {
      final productFile = File(
        p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'product',
          'product.dart',
        ),
      );
      await productFile.writeAsString('class Product { final String id; }\n');
      await runZfa(['cache', 'adapter', 'Product']);
      await productFile.writeAsString(
        'class Product { final String id; final Category category; }\n',
      );

      final drifted = await runZfa(['cache', 'verify', 'Product']);
      expect(drifted.exitCode, 1, reason: 'drift must fail the gate');

      final healed = await runZfa(['cache', 'adapter', 'Product']);
      expect(healed.exitCode, 0, reason: 'stdout=${healed.stdout}');

      final result = await runZfa(['cache', 'verify', 'Product']);
      expect(
        result.exitCode,
        0,
        reason: 're-registration must heal the drift: ${result.stdout}',
      );
    });

    test('hand-edited registrar → exit 1 with a stale finding (receipt '
        'digest drift)', () async {
      await runZfa(['cache', 'adapter', 'Product']);

      // Hand-edit the registrar AFTER the receipt bound its bytes.
      final registrarFile = File(
        p.join(workspace.path, 'lib', 'src', 'cache', 'hive_registrar.dart'),
      );
      await registrarFile.writeAsString(
        '${await registrarFile.readAsString()}\n// hand edit\n',
      );

      final result = await runZfa(['cache', 'verify', 'Product']);

      expect(result.exitCode, 1, reason: 'stdout=${result.stdout}');
      expect(result.stdout, contains('stale'));
      expect(result.stdout, contains('--> fix:'));
    });

    test('--json emits a parseable cache.verify.v1 verdict object', () async {
      await runZfa(['cache', 'adapter', 'Product']);
      final registrarFile = File(
        p.join(workspace.path, 'lib', 'src', 'cache', 'hive_registrar.dart'),
      );
      await registrarFile.writeAsString(
        '${await registrarFile.readAsString()}\n// hand edit\n',
      );

      final result = await runZfa(['cache', 'verify', 'Product', '--json']);

      expect(result.exitCode, 1, reason: 'drift must set the exit code');
      final stdout = (result.stdout as String).trim();
      final decoded = _decodeJson(stdout);
      expect(decoded['schema'], 'cache.verify.v1');
      expect(decoded['ok'], isFalse);
      expect((decoded['findings'] as List), isNotEmpty);
      for (final finding in decoded['findings'] as List) {
        expect(finding['fix'], contains('zfa cache adapter'));
      }
    });
  });
}

dynamic _decodeJson(String text) {
  // The CLI may prefix non-JSON lines; parse from the first '{'.
  final start = text.indexOf('{');
  expect(start, greaterThanOrEqualTo(0), reason: 'no JSON object in: $text');
  return jsonDecode(text.substring(start));
}
