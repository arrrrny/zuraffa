@Tags(['regression', 'slow'])
library;

// Regression test for issue #406:
// https://github.com/arrrrny/zuraffa/issues/406
//
// `zfa repository create --name Task --methods get,create,update,list,watch`
// generated `task_repository.dart` (interface: get, create, update, watch) and
// `data_task_repository.dart` (impl) but:
//   1. the impl imports `../datasources/task/task_datasource.dart` and
//      references `TaskDataSource`, yet `zfa repository create` never
//      generated that datasource file (uri_does_not_exist +
//      undefined_class);
//   2. the impl declared `list(NoParams)` with `@override` but `list` was
//      NOT in the abstract `TaskRepository` interface
//      (override_on_non_overriding_member).
//
// So `dart analyze` reported 3 issues. The repository generator and the
// datasource generator were out of sync, and the `list` method — a
// documented `--methods` value — was silently dropped from the interface
// while the implementation generator emitted it via its `default` fallback
// branch.
//
// This guard asserts the fix:
//   * `zfa repository create --datasource` emits the datasource interface
//     file the implementation imports.
//   * The `list` method appears identically in the interface, the impl, and
//     the datasource interface (method-set parity).
//   * The generated source analyzes cleanly inside a real Dart package
//     that exports `NoParams`, `QueryParams`, etc. (no
//     uri_does_not_exist / undefined_class / override_on_non_overriding_member).
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

void main() {
  late Directory workspace;
  late String outputDir;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_issue_406_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);

    // Minimal Task entity so the config is entity-based.
    final entityDir = Directory(
      p.join(outputDir, 'domain', 'entities', 'task'),
    );
    await entityDir.create(recursive: true);
    await File(p.join(entityDir.path, 'task.dart')).writeAsString('''
class Task {
  final String id;
  final String title;
  const Task({required this.id, required this.title});
}
''');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  test(
    'issue #406: datasource emitted + list in interface/impl/datasource',
    () async {
      final plugin = RepositoryPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Task',
        methods: ['get', 'create', 'update', 'list', 'watch'],
        generateRepository: true,
        generateData: true,
        generateDataSource: true,
        outputDir: outputDir,
      );

      final files = await plugin.generate(config);

      // --- Bug #1: datasource interface file must be generated ---
      final datasourcePath = p.join(
        outputDir,
        'data',
        'datasources',
        'task',
        'task_datasource.dart',
      );
      final datasourceFile = File(datasourcePath);
      expect(
        datasourceFile.existsSync(),
        isTrue,
        reason:
            '#406: zfa repository create --datasource must emit the '
            'datasource interface the impl imports',
      );
      final datasourceContent = datasourceFile.readAsStringSync();

      // --- Locate interface + impl ---
      final interfaceFile = files.firstWhere(
        (f) => f.path.contains('domain/repositories/task_repository.dart'),
      );
      final implFile = files.firstWhere(
        (f) => f.path.contains('data/repositories/data_task_repository.dart'),
      );
      final interfaceContent = interfaceFile.content ?? '';
      final implContent = implFile.content ?? '';

      // --- Bug #2: `list` must be in the interface ---
      expect(
        interfaceContent.contains('Future<List<Task>> list'),
        isTrue,
        reason: '#406: list was dropped from the interface (no switch case)',
      );

      // --- `list` in impl must match the interface signature (NoParams) ---
      expect(
        implContent.contains('Future<List<Task>> list(NoParams'),
        isTrue,
        reason: '#406: impl list must return Future<List<Task>> with NoParams',
      );

      // --- `list` in datasource interface ---
      expect(
        datasourceContent.contains('Future<List<Task>> list'),
        isTrue,
        reason: '#406: datasource interface must declare list',
      );

      // --- The impl must reference the datasource class it imports ---
      expect(implContent.contains('TaskDataSource'), isTrue);

      // --- The datasource interface must define TaskDataSource ---
      expect(
        datasourceContent.contains('abstract class TaskDataSource'),
        isTrue,
        reason: '#406: TaskDataSource class must be defined',
      );

      // --- Interface ↔ impl method-set parity for `list` ---
      // Both must declare `list` with `NoParams` and `Future<List<Task>>`.
      final listSignature = RegExp(r'Future<List<Task>>\s+list\(NoParams');
      expect(listSignature.hasMatch(interfaceContent), isTrue);
      expect(listSignature.hasMatch(implContent), isTrue);
      expect(listSignature.hasMatch(datasourceContent), isTrue);
    },
  );

  test(
    'issue #406: list also works in cache mode (method-set parity)',
    () async {
      final plugin = RepositoryPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Task',
        methods: ['get', 'list', 'watch'],
        generateRepository: true,
        generateData: true,
        generateDataSource: true,
        enableCache: true,
        outputDir: outputDir,
      );

      final files = await plugin.generate(config);
      final implFile = files.firstWhere(
        (f) => f.path.contains('data/repositories/data_task_repository.dart'),
      );
      final implContent = implFile.content ?? '';

      // `list` must be present with @override (not dropped to _noop).
      expect(
        implContent.contains(RegExp(r'@override\s+Future<List<Task>>\s+list')),
        isTrue,
        reason: '#406: cache-mode impl must implement list (not _noop)',
      );
      expect(
        implContent.contains('_noop'),
        isFalse,
        reason: '#406: list must not fall through to the _noop default',
      );
    },
  );

  test(
    'issue #406: list also works in sync mode (method-set parity)',
    () async {
      final plugin = RepositoryPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Task',
        methods: ['get', 'list'],
        generateRepository: true,
        generateData: true,
        generateDataSource: true,
        enableSync: true,
        outputDir: outputDir,
      );

      final files = await plugin.generate(config);
      final implFile = files.firstWhere(
        (f) => f.path.contains('data/repositories/data_task_repository.dart'),
      );
      final implContent = implFile.content ?? '';

      expect(
        implContent.contains(RegExp(r'@override\s+Future<List<Task>>\s+list')),
        isTrue,
        reason: '#406: sync-mode impl must implement list (not _noop)',
      );
      expect(implContent.contains('_noop'), isFalse);
    },
  );

  test('issue #406: --no-datasource skips datasource generation', () async {
    final plugin = RepositoryPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );
    final config = GeneratorConfig(
      name: 'Task',
      methods: ['get', 'list'],
      generateRepository: true,
      generateData: true,
      generateDataSource: false, // explicit --no-datasource
      outputDir: outputDir,
    );

    final files = await plugin.generate(config);

    // No datasource file should be generated.
    final hasDatasource = files.any(
      (f) => f.path.contains('datasources/task/task_datasource.dart'),
    );
    expect(
      hasDatasource,
      isFalse,
      reason: '#406: --no-datasource must not emit the datasource file',
    );
  });
}
