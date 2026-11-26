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
import 'package:zorphy_annotation/zorphy_annotation.dart';

final class Order {
  const Order.fromTrusted({required this.id, required this.label});

  final String id;
  final String label;

  Order copyWith({String? id, String? label}) => Order.fromTrusted(
    id: id ?? this.id,
    label: label ?? this.label,
  );

  Map<String, dynamic> toJson() => {'id': id, 'label': label};

  factory Order.fromJson(Map<String, dynamic> json) => Order.fromTrusted(
    id: json['id'] as String,
    label: json['label'] as String,
  );
}

abstract final class OrderFields {
  static const ZorphyField<Order, String> id = ZorphyField<Order, String>(
    name: 'id', jsonKey: 'id', pointer: '/id', get: _getId, set: _setId,
  );
  static const ZorphyField<Order, String> label =
      ZorphyField<Order, String>(
        name: 'label', jsonKey: 'label', pointer: '/label',
        get: _getLabel, set: _setLabel,
      );
  static final List<ZorphyField<Order, Object?>> all = [id.asObject, label.asObject];

  static String _getId(Order root) => root.id;
  static Order _setId(Order root, String value) => root.copyWith(id: value);
  static String _getLabel(Order root) => root.label;
  static Order _setLabel(Order root, String value) => root.copyWith(label: value);
}

final class OrderPatch implements ZorphyPatch<Order> {
  const OrderPatch({this.id = const PatchValue.unchanged(), this.label = const PatchValue.unchanged()});

  final PatchValue<String> id;
  final PatchValue<String> label;

  @override
  bool get isEmpty => id.isUnchanged && label.isUnchanged;
  @override
  bool get isNotEmpty => !isEmpty;

  @override
  Order apply(covariant Order target) => target.copyWith(
    id: id.isUnchanged ? target.id : id.valueOrNull,
    label: label.isUnchanged ? target.label : label.valueOrNull,
  );

  @override
  ZorphyPatch<Order> compose(covariant ZorphyPatch<Order> next) => next;

  @override
  ZorphyPatch<Order> invert(Order before) => OrderPatch(
    id: PatchValue<String>.set(before.id),
    label: PatchValue<String>.set(before.label),
  );

  @override
  Map<String, Object?> toWire() => const <String, Object?>{};
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
    expect(
      File(sqlitePath).existsSync(),
      isTrue,
      reason: 'sqlite datasource must be generated',
    );

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
      reason:
          'generated sqlite datasource must be dart-format clean:\n'
          '${format.stdout}\n${format.stderr}',
    );
  });
}

/// Like [writePubspec] but with `sqlite3` added — the generated data source
/// imports `package:sqlite3/sqlite3.dart`.
Future<void> _writePubspecWithSqlite3(RegressionWorkspace workspace) async {
  final repoRoot = await findProjectRoot();
  final content =
      '''
name: zuraffa_test_app
environment:
  sdk: ">=3.8.0 <4.0.0"
dependencies:
  zuraffa:
    path: ${normalizePath(repoRoot)}
  get_it: ^9.0.0
  sqlite3: ^2.4.0
dev_dependencies:
dependency_overrides:
  meta: ^1.18.0
  analyzer: ^12.0.0
''';
  await File('${workspace.directory.path}/pubspec.yaml').writeAsString(content);
}

String normalizePath(String p) => p.replaceAll('\\', '/');
