import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

/// Bug #989 — stale use case test imports remain after the #921 rejection.
///
/// When the entity pipeline refuses to (re)generate use cases whose action
/// methods are absent from the entity's repository interface (#921), any
/// pre-existing test files that import those never-generated use case files
/// stay in the suite and break `dart test` at load time. The suite never
/// re-runs to a clean baseline.
///
/// Expected: when #921 rejects a use case, the corresponding stale test
/// imports are removed — test files referencing non-existent use cases are
/// stale by construction.
void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_989_');
    projectRoot = tempDir.path;
    outputDir = Directory('${tempDir.path}/lib/src').path;
    await File(
      '${tempDir.path}/pubspec.yaml',
    ).writeAsString('name: task_app\n');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('bug #989 — stale usecase test imports after #921 rejection', () {
    test('removes stale imports and their tests from an aggregate test file '
        'while keeping the actually-existing surface', () async {
      await _scaffoldEntity(outputDir, 'Task');
      // Repository from a prior CRUD-only run: only 'get' exists, so the
      // run below rejects 'create' (#921) and 'cancel' is not even a
      // valid entity method — neither usecase file will ever exist.
      await _scaffoldRepository(outputDir, 'Task', ['get']);

      final staleTest = File(
        '$projectRoot/test/unit/test_task_usecases_test.dart',
      );
      await staleTest.create(recursive: true);
      await staleTest.writeAsString('''
import 'package:test/test.dart';
import 'package:task_app/src/domain/entities/task/task.dart';
import 'package:task_app/src/domain/usecases/task/cancel_task_usecase.dart';
import 'package:task_app/src/domain/usecases/task/create_task_usecase.dart';
import 'package:task_app/src/domain/usecases/task/get_task_usecase.dart';

void main() {
  group('TaskUseCases', () {
    test('cancel', () {
      expect(CancelTaskUseCase, isNotNull);
    });
    test('create', () {
      expect(CreateTaskUseCase, isNotNull);
    });
    test('get', () {
      expect(GetTaskUseCase, isNotNull);
    });
  });
}
''');

      final plugin = UseCasePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Task',
        methods: ['get', 'create'],
        outputDir: outputDir,
      );
      await plugin.generate(config);

      final content = staleTest.readAsStringSync();
      expect(
        content.contains('cancel_task_usecase.dart'),
        isFalse,
        reason:
            'The import of the never-generated cancel_task_usecase.dart '
            'must be removed — the suite cannot load while it is present.',
      );
      expect(
        content.contains('create_task_usecase.dart'),
        isFalse,
        reason:
            'The import of the #921-rejected create_task_usecase.dart must '
            'be removed — the suite cannot load while it is present.',
      );
      expect(
        content.contains('get_task_usecase.dart'),
        isTrue,
        reason:
            'The import of the actually-existing get_task_usecase.dart '
            'must be kept.',
      );
      expect(
        content.contains('CancelTaskUseCase'),
        isFalse,
        reason: 'Tests of the non-existent usecase must be removed.',
      );
      expect(
        content.contains('CreateTaskUseCase'),
        isFalse,
        reason: 'Tests of the rejected usecase must be removed.',
      );
      expect(
        content.contains('GetTaskUseCase'),
        isTrue,
        reason: 'Tests of the existing usecase must be kept.',
      );
    });

    test('deletes a wholly stale per-method usecase test file', () async {
      await _scaffoldEntity(outputDir, 'Task');
      // Repository from a prior run: only 'get' exists, so requesting
      // 'toggle' triggers the #921 rejection that unlocks the sweep.
      await _scaffoldRepository(outputDir, 'Task', ['get']);

      final staleTest = File(
        '$projectRoot/test/domain/usecases/task/cancel_task_usecase_test.dart',
      );
      await staleTest.create(recursive: true);
      await staleTest.writeAsString('''
import 'package:test/test.dart';
import 'package:task_app/src/domain/entities/task/task.dart';
import 'package:task_app/src/domain/usecases/task/cancel_task_usecase.dart';

void main() {
  test('cancel', () {
    expect(CancelTaskUseCase, isNotNull);
  });
}
''');

      final plugin = UseCasePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Task',
        methods: ['get', 'toggle'],
        outputDir: outputDir,
      );
      await plugin.generate(config);

      expect(
        staleTest.existsSync(),
        isFalse,
        reason:
            'A test file whose only usecase import is non-existent is stale '
            'by construction and must be deleted so the suite can load.',
      );
    });

    test('leaves test files untouched when #921 rejects nothing', () async {
      await _scaffoldEntity(outputDir, 'Task');
      await _scaffoldRepository(outputDir, 'Task', ['get', 'create']);

      final staleTest = File(
        '$projectRoot/test/unit/test_task_usecases_test.dart',
      );
      await staleTest.create(recursive: true);
      const original = '''
import 'package:task_app/src/domain/usecases/task/get_task_usecase.dart';

void main() {
  test('get', () {
    expect(GetTaskUseCase, isNotNull);
  });
}
''';
      await staleTest.writeAsString(original);

      final plugin = UseCasePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Task',
        methods: ['get', 'create'],
        outputDir: outputDir,
      );
      await plugin.generate(config);

      expect(
        staleTest.readAsStringSync(),
        original,
        reason:
            'With no #921 rejection the cleanup must not run — behavior '
            'outside the rejection path is unchanged.',
      );
    });
  });
}

/// Scaffolds a minimal entity file at the canonical v5 location.
Future<void> _scaffoldEntity(String outputDir, String entityName) async {
  final snake = _camelToSnake(entityName);
  final dir = Directory('$outputDir/domain/entities/$snake');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$snake.dart');
  await file.writeAsString('class $entityName {}\n');
}

/// Scaffolds a repository interface at the canonical location declaring
/// exactly [methods], mimicking the output of a prior `zfa make` run.
Future<void> _scaffoldRepository(
  String outputDir,
  String entityName,
  List<String> methods,
) async {
  final snake = _camelToSnake(entityName);
  final dir = Directory('$outputDir/domain/repositories');
  await dir.create(recursive: true);
  final file = File('${dir.path}/${snake}_repository.dart');
  final signatures = methods
      .map((m) {
        switch (m) {
          case 'get':
            return '  Future<$entityName> get(covariant dynamic params);';
          case 'update':
            return '  Future<$entityName> update(covariant dynamic params);';
          case 'toggle':
            return '  Future<$entityName> toggle(covariant dynamic params);';
          case 'delete':
            return '  Future<void> delete(covariant dynamic params);';
          default:
            return '  Future<List<$entityName>> $m(covariant dynamic params);';
        }
      })
      .join('\n');
  await file.writeAsString(
    'abstract class ${entityName}Repository {\n$signatures\n}\n',
  );
}

String _camelToSnake(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'([A-Z])'),
        (m) => '_${m.group(1)!.toLowerCase()}',
      )
      .replaceFirst(RegExp(r'^_'), '');
}
