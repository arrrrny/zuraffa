import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/datasource_check_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';
import 'package:zuraffa/src/plugins/sqlite/builders/sqlite_datasource_builder.dart';

/// Spec #977 — `zfa datasource check <Entity>`: parity gate between the
/// generated datasource interface and every generated implementation
/// (remote / local / sqlite variants).
///
/// Catches the #417 drift class at generation time: a method present in
/// the interface but missing from an implementation (or an @override in
/// an implementation that the interface does not declare) must exit 1
/// with a `--> fix:` line naming the method and the offending file.
///
/// Parity semantics (deliberate, documented):
/// - every PUBLIC method declared in the interface must be declared in
///   every implementation;
/// - every method an implementation marks `@override` must be declared
///   in the interface;
/// - extra public methods without `@override` (the local Hive variant's
///   `save`/`saveAll`/`clear`) are legitimate and never flagged.
Future<String> captureOutput(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_977_check_');
    projectRoot = tempDir.path;
    outputDir = '$projectRoot/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  Future<void> generateProduct({bool local = true}) async {
    final plugin = DataSourcePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(),
    );
    await plugin.generate(
      GeneratorConfig(
        name: 'Product',
        methods: const [
          'get',
          'getList',
          'create',
          'update',
          'delete',
          'watch',
        ],
        generateDataSource: true,
        generateLocal: local,
        outputDir: outputDir,
      ),
    );
  }

  CommandRunner<void> runner() {
    final command = DataSourceCheckCommand(projectRoot: projectRoot);
    return CommandRunner<void>('zfa', 'test')..addCommand(command);
  }

  group('check verb — positive', () {
    test('freshly generated interface + remote + local is at parity', () async {
      exitCode = 0;
      await generateProduct();

      final output = await captureOutput(
        () => runner().run(['check', 'Product']),
      );

      expect(exitCode, 0, reason: 'fresh generation must pass parity');
      expect(output, contains('parity'));
    });

    test('a full sqlite variant keeps parity (sqlite local variant)', () async {
      exitCode = 0;
      // Interface and sqlite variant are generated for the SAME method
      // set, so the gate must pass. (An interface declaring methods the
      // sqlite variant never received is genuine drift — covered by the
      // negative sqlite test below.)
      const methods = ['get', 'getList', 'create', 'update', 'delete'];
      final plugin = DataSourcePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );
      await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: methods,
          generateDataSource: true,
          generateLocal: false,
          outputDir: outputDir,
        ),
      );
      final builder = SqliteDataSourceBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );
      await builder.generate(
        GeneratorConfig(
          name: 'Product',
          methods: methods,
          generateDataSource: true,
          outputDir: outputDir,
        ),
      );

      final output = await captureOutput(
        () => runner().run(['check', 'Product']),
      );

      expect(exitCode, 0, reason: 'a complete sqlite variant must pass parity');
      expect(output, contains('sqlite'));

      // Spec #977 order 6: the sqlite local variant CONTENT is pinned —
      // the generated adapter implements the interface and carries the
      // documented storage model markers.
      final sqliteFile = File(
        '$outputDir/data/datasources/product/product_sqlite_datasource.dart',
      );
      expect(sqliteFile.existsSync(), isTrue);
      final content = sqliteFile.readAsStringSync();
      expect(content, contains('class ProductSqliteDataSource'));
      expect(content, contains('implements ProductDataSource'));
      for (final method in methods) {
        expect(
          content,
          contains('$method('),
          reason: 'sqlite variant must implement `$method`',
        );
      }
      expect(content, contains('PRAGMA journal_mode = WAL'));
    });
  });

  group('check verb — negative', () {
    test(
      'impl missing an interface method exits 1 naming method + file',
      () async {
        exitCode = 0;
        await generateProduct(local: false);
        final remoteFile = File(
          '$outputDir/data/datasources/product/product_remote_datasource.dart',
        );
        var source = remoteFile.readAsStringSync();
        // Deliberate drift: drop the `getList` implementation. The remote
        // impl method has a body, so match through its closing brace.
        final start = source.indexOf(
          '  @override\n  Future<List<Product>> getList(',
        );
        expect(start, greaterThan(0), reason: 'test fixture must find getList');
        final braceStart = source.indexOf('{', start);
        var depth = 0;
        var end = braceStart;
        for (var i = braceStart; i < source.length; i++) {
          if (source[i] == '{') depth++;
          if (source[i] == '}') depth--;
          if (depth == 0) {
            end = i + 1;
            break;
          }
        }
        source = source.substring(0, start) + source.substring(end);
        remoteFile.writeAsStringSync(source);

        final output = await captureOutput(
          () => runner().run(['check', 'Product']),
        );

        expect(exitCode, 1, reason: 'diverged impl must fail the parity gate');
        expect(output, contains('--> fix:'));
        expect(output, contains('getList'));
        expect(output, contains('product_remote_datasource.dart'));
      },
    );

    test('impl @override method absent from the interface exits 1', () async {
      exitCode = 0;
      await generateProduct(local: false);
      final remoteFile = File(
        '$outputDir/data/datasources/product/product_remote_datasource.dart',
      );
      final source = remoteFile.readAsStringSync();
      const drifted = '''
  @override
  Future<Product> purge(QueryParams<Product> params) async {
    throw UnimplementedError();
  }
''';
      final insertAt = source.lastIndexOf('}');
      remoteFile.writeAsStringSync(
        source.substring(0, insertAt) + drifted + source.substring(insertAt),
      );

      final output = await captureOutput(
        () => runner().run(['check', 'Product']),
      );

      expect(exitCode, 1, reason: '@override drift must fail the gate');
      expect(output, contains('--> fix:'));
      expect(output, contains('purge'));
    });

    test('sqlite variant missing interface methods is caught', () async {
      exitCode = 0;
      await generateProduct(local: false);
      // Hand-written diverged sqlite variant: implements the interface but
      // omits `delete` and `watch`.
      final dir = Directory('$outputDir/data/datasources/product');
      File('${dir.path}/product_sqlite_datasource.dart').writeAsStringSync('''
import 'product_datasource.dart';

class ProductSqliteDataSource implements ProductDataSource {
  ProductSqliteDataSource();

  @override
  Future<Product> get(QueryParams<Product> params) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Product>> getList(ListQueryParams<Product> params) async {
    throw UnimplementedError();
  }

  @override
  Future<Product> create(Product product) async {
    throw UnimplementedError();
  }

  @override
  Future<Product> update(UpdateParams<String, ProductPatch> params) async {
    throw UnimplementedError();
  }
}
''');

      final output = await captureOutput(
        () => runner().run(['check', 'Product']),
      );

      expect(exitCode, 1, reason: 'diverged sqlite variant must fail');
      expect(output, contains('--> fix:'));
      expect(output, contains('delete'));
      expect(output, contains('watch'));
      expect(output, contains('product_sqlite_datasource.dart'));
    });

    test('missing interface file exits 1 with a fix line', () async {
      exitCode = 0;
      Directory(
        '$outputDir/data/datasources/product',
      ).createSync(recursive: true);

      final output = await captureOutput(
        () => runner().run(['check', 'Product']),
      );

      expect(exitCode, 1);
      expect(output, contains('--> fix:'));
    });
  });

  group('check verb — usage', () {
    test('missing entity argument exits 64', () async {
      exitCode = 0;

      final output = await captureOutput(() => runner().run(['check']));

      expect(
        exitCode,
        64,
        reason: 'missing args is a usage error, not success',
      );
      expect(output, contains('Usage'));
    });

    test(
      'unknown entity (no datasources dir at all) exits 1 with fix line',
      () async {
        exitCode = 0;

        final output = await captureOutput(
          () => runner().run(['check', 'Product']),
        );

        expect(exitCode, 1);
        expect(output, contains('--> fix:'));
      },
    );
  });
}
