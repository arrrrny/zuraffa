@Tags(['integration', 'slow'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../helpers/project_root.dart';
import '../regression/regression_test_utils.dart';

// Integration test for issue #464:
// https://github.com/arrrrny/zuraffa/issues/464
//
// `zfa make <Entity> --sqlite` must generate a compiling
// `<Entity>SqliteDataSource` (package:sqlite3) implementing the generated
// `<Entity>DataSource` interface — including schema creation, WAL mode and
// versioned migrations — so server-side projects no longer hand-write the
// SQLite boilerplate.
void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('sqlite_compilation_test');
    await _writePubspecWithSqlite3(workspace);
    await runFlutterPubGet(workspace);
    final entityDir = Directory('${workspace.outputDir}/domain/entities/order');
    entityDir.createSync(recursive: true);
    File('${entityDir.path}/order.dart').writeAsStringSync('''
class Order {
  final String id;
  final String label;

  const Order({required this.id, required this.label});

  Map<String, dynamic> toJson() => {'id': id, 'label': label};

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        label: json['label'] as String,
      );
}

class OrderPatch {
  final String? id;
  final String? label;

  const OrderPatch({this.id, this.label});

  Order applyTo(Order base) => base;
}
''');
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test('generated sqlite datasource should compile', () async {
    final config = GeneratorConfig(
      name: 'Order',
      methods: const ['get', 'getList', 'create', 'update', 'delete'],
      generateData: true,
      enableSqlite: true,
      outputDir: outputDir,
    );
    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: true,
      ),
    );
    await generator.generate();

    final sqlitePath =
        '$outputDir/data/datasources/order/order_sqlite_datasource.dart';
    expect(File(sqlitePath).existsSync(), isTrue,
        reason: 'sqlite datasource must be generated');

    final analyze = await runDartAnalyze(workspace);
    expect(
      analyze.exitCode,
      0,
      reason:
          'generated code must analyze cleanly:\n${analyze.stdout}\n${analyze.stderr}',
    );
  });

  test('generated sqlite datasource is formatted', () async {
    final config = GeneratorConfig(
      name: 'Order',
      methods: const ['get', 'getList', 'create', 'update', 'delete'],
      generateData: true,
      enableSqlite: true,
      outputDir: outputDir,
    );
    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: true,
      ),
    );
    await generator.generate();

    final format = await runDartFormatCheckPaths(workspace, [
      'lib/src/data/datasources/order/order_sqlite_datasource.dart',
    ]);
    expect(
      format.exitCode,
      0,
      reason: 'generated sqlite datasource must be dart-format clean:\n'
          '${format.stdout}\n${format.stderr}',
    );
  });
}

/// Like [writePubspec] but with `sqlite3` added — the generated data source
/// imports `package:sqlite3/sqlite3.dart`.
Future<void> _writePubspecWithSqlite3(RegressionWorkspace workspace) async {
  final repoRoot = await findProjectRoot();
  final content = '''
name: zuraffa_test_app
environment:
  sdk: ">=3.8.0 <4.0.0"
dependencies:
  zuraffa:
    path: ${normalizePath(repoRoot)}
  get_it: ^9.0.0
  sqlite3: ^2.4.0
dev_dependencies:
  mocktail: ^1.0.4
dependency_overrides:
  meta: ^1.18.0
  analyzer: ^12.0.0
''';
  await File('${workspace.directory.path}/pubspec.yaml').writeAsString(content);
}

String normalizePath(String p) => p.replaceAll('\\', '/');
