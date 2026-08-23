import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/sqlite/builders/sqlite_datasource_builder.dart';

/// Tests for the SQLite data source generator (issue #464):
/// `zfa sqlite adapter <Entity>` must emit a compiling
/// `<Entity>SqliteDataSource implements <Entity>DataSource` with schema
/// creation (WAL + table + schema_version), id-keyed SQL writes, and
/// mock-compatible read semantics.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_sqlite_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  SqliteDataSourceBuilder builder() => SqliteDataSourceBuilder(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: true),
  );

  Future<String> generate({
    List<String> methods = const [
      'get',
      'getList',
      'create',
      'update',
      'delete',
    ],
    String idField = 'id',
    String idFieldType = 'String',
  }) async {
    final files = await builder().generate(
      GeneratorConfig(
        name: 'Task',
        methods: methods,
        idField: idField,
        idFieldType: idFieldType,
        outputDir: outputDir,
      ),
    );
    final file = files.firstWhere(
      (f) => f.path.contains('task_sqlite_datasource.dart'),
    );
    return file.content ?? '';
  }

  group('#464 sqlite adapter generation', () {
    test('emits the datasource class implementing the interface', () async {
      final content = await generate();

      expect(content, contains('class TaskSqliteDataSource'));
      expect(content, contains('implements TaskDataSource'));
      expect(
        content,
        contains("import '../../../domain/entities/task/task.dart';"),
        reason: 'the generated adapter must import its entity',
      );
      expect(
        content,
        contains("import 'task_datasource.dart';"),
        reason: 'the generated adapter must import the datasource interface',
      );
      expect(
        content,
        contains("import 'package:sqlite3/sqlite3.dart';"),
        reason: 'the adapter is backed by package:sqlite3',
      );
    });

    test(
      'ensures the schema with WAL journaling and a version marker',
      () async {
        final content = await generate();

        expect(content, contains('PRAGMA journal_mode = WAL'));
        expect(
          content,
          contains('CREATE TABLE IF NOT EXISTS tasks'),
          reason: 'the entity table is created on open',
        );
        expect(content, contains('id TEXT PRIMARY KEY, data TEXT NOT NULL'));
        expect(
          content,
          contains('CREATE TABLE IF NOT EXISTS schema_version'),
          reason: 'a schema_version table is the migration scaffolding',
        );
        expect(
          content,
          contains('INSERT OR REPLACE INTO schema_version'),
          reason: 'the current schema version is stamped',
        );
        expect(
          content,
          contains('static const int _schemaVersion = 1;'),
          reason: 'the version is a constant the migration logic compares',
        );
      },
    );

    test('writes are id-keyed SQL statements', () async {
      final content = await generate();

      expect(
        content,
        contains('INSERT OR REPLACE INTO tasks (id, data) VALUES (?, ?)'),
        reason: 'create persists the row',
      );
      expect(
        content,
        contains("jsonEncode(task.toJson())"),
        reason: 'rows are serialized via the entity JSON',
      );
      expect(
        content,
        contains('UPDATE tasks SET data = ? WHERE id = ?'),
        reason: 'update writes the patched row back',
      );
      expect(
        content,
        contains('DELETE FROM tasks WHERE id = ?'),
        reason: 'delete removes the row by id',
      );
      expect(
        content,
        contains('params.data.applyTo(existing)'),
        reason: 'update applies the TaskPatch like the mock datasource',
      );
      expect(
        content,
        contains('notFoundFailure'),
        reason: 'update throws notFoundFailure when the row is missing',
      );
    });

    test('reads mirror the mock datasource semantics', () async {
      final content = await generate();

      expect(
        content,
        contains('.query(params)'),
        reason: 'get filters rows in memory via the query extension',
      );
      expect(
        content,
        contains('SELECT data FROM tasks'),
        reason: 'reads load the decoded rows',
      );
      expect(
        content,
        contains('params.offset'),
        reason: 'getList applies offset like the mock datasource',
      );
      expect(
        content,
        contains('params.limit'),
        reason: 'getList applies limit like the mock datasource',
      );
      expect(
        content,
        contains('Task.fromJson(jsonDecode('),
        reason: 'rows are decoded back into entities',
      );
    });

    test('generates only the requested methods', () async {
      final content = await generate(methods: const ['get', 'create']);

      expect(content, contains('Future<Task> get('));
      expect(content, contains('Future<Task> create('));
      expect(
        content,
        isNot(contains('Future<void> delete(')),
        reason: 'unrequested methods must not be emitted',
      );
      expect(content, isNot(contains('Future<List<Task>> getList(')));
    });

    test('emits watch streams and toggle when requested', () async {
      final content = await generate(
        methods: const ['watch', 'watchList', 'toggle'],
      );

      expect(content, contains('Stream<Task> watch('));
      expect(content, contains('Stream<List<Task>> watchList('));
      expect(content, contains('copyWithField('));
      expect(content, contains('Stream.periodic'));
    });

    test('respects a custom id field', () async {
      final content = await generate(idField: 'taskId');

      expect(
        content,
        contains('task.taskId,'),
        reason: 'create keys rows by the entity\'s real id field',
      );
      expect(
        content,
        contains('updated.taskId'),
        reason: 'update writes back keyed by the entity\'s real id field',
      );
    });

    test('NoParams entities delete the whole table', () async {
      final content = await generate(
        methods: const ['delete'],
        idFieldType: 'NoParams',
      );

      expect(
        content,
        contains("DELETE FROM tasks'"),
        reason: 'a singleton entity has no id to key on',
      );
    });
  });
}
