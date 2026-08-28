// Regression test for issue #463: the mock datasource must be a genuine
// in-memory implementation — create/update/delete (and toggle) must mutate
// the backing `XMockData.xs` collection so a create→get lifecycle works.
//
// Before the fix, create/update/delete returned the item (or void) without
// touching the collection: `CreateTaskUseCase` → `GetTaskUseCase` threw
// `StateError: Bad state: No element` because the created task was never
// added to `TaskMockData.tasks`.
//
// The assertions pin the persistence statements in the generated
// `task_mock_datasource.dart` source, following the established
// mock_builder_test.dart pattern (direct builder + temp dir).
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_builder.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_mock_463_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> generateTaskMockDataSource({
    List<String> methods = const [
      'get',
      'getList',
      'create',
      'update',
      'delete',
      'toggle',
    ],
    String idFieldType = 'String',
  }) async {
    final entityDir = Directory('$outputDir/domain/entities/task');
    await entityDir.create(recursive: true);
    final entityFile = File('${entityDir.path}/task.dart');
    await entityFile.writeAsString(
      'class Task { final String id; final String spec; final String status; '
      'const Task(this.id, this.spec, this.status); }',
    );

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'Task',
        methods: methods,
        generateMock: true,
        idField: 'id',
        idFieldType: idFieldType,
        outputDir: outputDir,
      ),
    );

    final mockDataSourceFile = files.firstWhere(
      (f) => f.path.contains('task_mock_datasource.dart'),
      orElse: () => throw StateError(
        'mock datasource not generated; files: ${files.map((f) => f.path).join(', ')}',
      ),
    );
    return mockDataSourceFile.content ?? '';
  }

  group('#463 mock datasource persistence', () {
    test('create appends the item to the backing collection', () async {
      final content = await generateTaskMockDataSource();

      expect(
        content.contains('TaskMockData.tasks.add(item);'),
        isTrue,
        reason:
            'create must persist the created item so a follow-up '
            'get/getList can retrieve it',
      );
    });

    test(
      'update applies the patch and replaces the entry in the collection',
      () async {
        final content = await generateTaskMockDataSource();

        expect(
          content.contains('params.data.applyTo(existing)'),
          isTrue,
          reason: 'update must apply the TaskPatch to the existing entry',
        );
        expect(
          content.contains('TaskMockData.tasks[index] = updated;'),
          isTrue,
          reason:
              'update must write the patched entry back into the '
              'backing collection',
        );
        expect(
          content.contains('return updated;'),
          isTrue,
          reason: 'update must return the patched entity, not the stale one',
        );
      },
    );

    test('delete removes the entry from the backing collection', () async {
      final content = await generateTaskMockDataSource();

      expect(
        content.contains('TaskMockData.tasks.remove(existing);'),
        isTrue,
        reason: 'delete must actually remove the entry',
      );
    });

    test('toggle applies the field flip and replaces the entry', () async {
      final content = await generateTaskMockDataSource();

      expect(
        content.contains('copyWithField('),
        isTrue,
        reason: 'toggle must apply the field flip via copyWithField',
      );
      expect(
        content.contains('TaskMockData.tasks[index] = updated;'),
        isTrue,
        reason: 'toggle must persist the flipped entry',
      );
    });

    test(
      'update on a NoParams entity patches the head of the collection',
      () async {
        final content = await generateTaskMockDataSource(
          methods: const ['update'],
          idFieldType: 'NoParams',
        );

        expect(
          content.contains('params.data.applyTo(existing)'),
          isTrue,
          reason: 'NoParams update must still apply the patch',
        );
        expect(
          content.contains('TaskMockData.tasks[0] = updated;'),
          isTrue,
          reason: 'NoParams update must persist into the collection head',
        );
      },
    );
  });
}
