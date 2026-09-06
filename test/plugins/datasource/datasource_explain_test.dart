import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/datasource_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/datasource/capabilities/create_datasource_capability.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

/// Spec #1131 (order 3) — `--explain` on the datasource create path.
///
/// `zfa datasource create <Entity> --explain` describes — without
/// generating anything — which datasource types are in play for the
/// entity (remote/local generated here; mock/sqlite delegated to their
/// own plugins), which entity fields map to which interface methods
/// (id-field → UpdateParams/DeleteParams/ToggleParams, entity →
/// get/create/watch), and the interface shape (the method signatures the
/// generation would emit).
void main() {
  late Directory tempDir;
  late String originalCwd;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_1131_explain_');
    originalCwd = Directory.current.path;
    Directory.current = tempDir.path;
  });

  tearDown(() async {
    Directory.current = originalCwd;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  CreateDataSourceCapability capability() {
    final plugin = DataSourcePlugin(
      outputDir: '${tempDir.path}/lib/src',
      options: const GeneratorOptions(),
    );
    return CreateDataSourceCapability(plugin, projectRoot: tempDir.path);
  }

  test(
    'capability --explain returns the explanation and generates NOTHING',
    () async {
      final result = await capability().execute({
        'name': 'Product',
        'local': true,
        'remote': true,
        'explain': true,
      });

      expect(result.success, isTrue, reason: result.message);
      final explain = result.data?['explain'] as String?;
      expect(explain, isNotNull);

      // Datasource types (remote/local/mock/sqlite) are all described.
      expect(explain!, contains('remote'));
      expect(explain, contains('local'));
      expect(explain, contains('mock'));
      expect(explain, contains('sqlite'));

      // Nothing was generated.
      expect(result.files, isEmpty);
      expect(
        Directory('${tempDir.path}/lib/src/data').existsSync(),
        isFalse,
        reason: '--explain is read-only: no datasource files on disk',
      );
    },
  );

  test(
    'explanation maps entity fields to methods (id field → update/delete)',
    () async {
      final snakeDir = Directory(
        '${tempDir.path}/lib/src/domain/entities/product',
      );
      snakeDir.createSync(recursive: true);
      File('${snakeDir.path}/product.dart').writeAsStringSync(
        'class Product {\n'
        '  const Product({required this.id, required this.name});\n'
        '  final String id;\n'
        '  final String name;\n'
        '}\n',
      );

      final result = await capability().execute({
        'name': 'Product',
        'remote': true,
        'explain': true,
      });
      final explain = result.data?['explain'] as String?;

      // The id field and its type appear in the field→method mapping.
      expect(explain, contains('id'));
      expect(explain, contains('String'));
      expect(explain, contains('update'));
      expect(explain, contains('delete'));
      // The entity flows through the entity-typed methods.
      expect(explain, contains('Product'));
      expect(explain, contains('get'));
    },
  );

  test(
    'explanation includes the interface shape (method signatures)',
    () async {
      final result = await capability().execute({
        'name': 'Product',
        'methods': ['get', 'update', 'delete'],
        'remote': true,
        'explain': true,
      });
      final explain = result.data?['explain'] as String?;

      // The interface shape: the signatures the generation would emit.
      expect(explain, contains('ProductDataSource'));
      expect(explain, contains('Future<Product> get(QueryParams<Product>)'));
      expect(
        explain,
        contains('Future<Product> update(UpdateParams<String, ProductPatch>)'),
      );
      expect(explain, contains('Future<void> delete(DeleteParams<String>)'));
    },
  );

  test(
    'the create subcommand parser accepts --explain (schema-declared flag)',
    () {
      final plugin = DataSourcePlugin(
        outputDir: '${tempDir.path}/lib/src',
        options: const GeneratorOptions(),
      );
      final cmd = plugin.createCommand();
      final create = cmd.subcommands['create'];
      expect(create, isNotNull);
      expect(
        create!.argParser.options.containsKey('explain'),
        isTrue,
        reason:
            'the capability inputSchema declares explain — the CLI '
            'grammar must accept it',
      );
    },
  );

  test(
    'parent datasource command --explain prints the plan and generates nothing',
    () async {
      final plugin = DataSourcePlugin(
        outputDir: '${tempDir.path}/lib/src',
        options: const GeneratorOptions(),
      );
      final output = <String>[];
      final cmd = _InjectableDataSourceCommand(plugin)
        ..accept(['--explain', 'Product']);
      await runZonedGuarded(
        () => cmd.run(),
        (error, stack) => output.add('UNCAUGHT: $error'),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => output.add(line),
        ),
      );
      final text = output.join('\n');
      expect(text, isNot(contains('UNCAUGHT')));
      expect(text, contains('remote'));
      expect(text, contains('ProductDataSource'));
      expect(Directory('${tempDir.path}/lib/src/data').existsSync(), isFalse);
    },
  );
}

/// DataSourceCommand with a hand-parsed ArgResults — the standalone
/// entity-positional path (mirrors the receipts test harness).
class _InjectableDataSourceCommand extends DataSourceCommand {
  _InjectableDataSourceCommand(super.plugin);

  ArgResults? injected;

  @override
  ArgResults? get argResults => injected ?? super.argResults;

  void accept(List<String> args) => injected = argParser.parse(args);
}
