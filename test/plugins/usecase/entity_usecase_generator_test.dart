import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_usecase_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('useZorphy flag for update method in entity usecase', () {
    test(
      'entity usecase emits EntityPatch when useZorphy=true (default)',
      () async {
        // Scaffold the entity file
        await _scaffoldEntity(outputDir, 'Product');

        final plugin = UseCasePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'Product',
          methods: ['update'],
          useZorphy: true,
          outputDir: outputDir,
        );
        final files = await plugin.generate(config);
        expect(files.isNotEmpty, isTrue);
        final content = files.first.content ?? '';

        // With useZorphy=true (default), should emit ProductPatch
        expect(
          content.contains('UpdateParams<String, ProductPatch>'),
          isTrue,
          reason: 'useZorphy=true should emit EntityPatch for update params',
        );
        expect(
          content.contains('Partial<Product>'),
          isFalse,
          reason: 'useZorphy=true should NOT emit Partial<Entity>',
        );
      },
    );

    test('entity usecase emits Partial<Entity> when useZorphy=false', () async {
      // Scaffold the entity file
      await _scaffoldEntity(outputDir, 'Product');

      final plugin = UseCasePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Product',
        methods: ['update'],
        useZorphy: false,
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);
      expect(files.isNotEmpty, isTrue);
      final content = files.first.content ?? '';

      // With useZorphy=false, should emit Partial<Product>
      expect(
        content.contains('UpdateParams<String, Partial<Product>>'),
        isTrue,
        reason: 'useZorphy=false should emit Partial<Entity> for update params',
      );
      // The #942 hide clause names ProductPatch on the barrel import by
      // design — the update path must not USE it, so check the body
      // only, imports excluded.
      final body = content
          .split('\n')
          .where((line) => !line.trim().startsWith('import '))
          .join('\n');
      expect(
        body.contains('ProductPatch'),
        isFalse,
        reason: 'useZorphy=false should NOT emit EntityPatch',
      );
    });
  });

  group('issue #921 — conservative repository-interface guard', () {
    test(
      'skips usecases whose method is missing from the existing repository',
      () async {
        await _scaffoldEntity(outputDir, 'Task');
        // Repository from a prior CRUD-only run: no 'toggle' method.
        await _scaffoldRepository(outputDir, 'Task', ['get', 'update']);

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
          methods: ['get', 'update', 'toggle'],
          outputDir: outputDir,
        );
        final files = await plugin.generate(config);

        final paths = files.map((f) => f.path).toList();
        expect(
          paths.any((p) => p.contains('toggle_task_usecase.dart')),
          isFalse,
          reason:
              'TaskRepository has no toggle method — the toggle usecase must '
              'not be generated (it would call repository.toggle and fail to '
              'compile)',
        );
        expect(
          paths.any((p) => p.contains('get_task_usecase.dart')),
          isTrue,
          reason: 'get exists on the repository, its usecase must be generated',
        );
        expect(
          paths.any((p) => p.contains('update_task_usecase.dart')),
          isTrue,
          reason:
              'update exists on the repository, its usecase must be generated',
        );
      },
    );

    test(
      'generates usecases for methods that exist on the repository interface',
      () async {
        await _scaffoldEntity(outputDir, 'Task');
        await _scaffoldRepository(outputDir, 'Task', [
          'get',
          'update',
          'toggle',
        ]);

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
          methods: ['get', 'update', 'toggle'],
          outputDir: outputDir,
        );
        final files = await plugin.generate(config);

        final paths = files.map((f) => f.path).toList();
        expect(
          paths.any((p) => p.contains('toggle_task_usecase.dart')),
          isTrue,
          reason:
              'toggle is declared on TaskRepository, its usecase must be '
              'generated',
        );
      },
    );

    test('fails open when the repository interface does not exist', () async {
      await _scaffoldEntity(outputDir, 'Task');
      // No repository file: the interface will be created by the same
      // generation plan (repository plugin in the plan) — nothing to
      // filter against, behavior must be unchanged.

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
        methods: ['get', 'update', 'toggle'],
        outputDir: outputDir,
      );
      final files = await plugin.generate(config);

      final paths = files.map((f) => f.path).toList();
      expect(
        paths.any((p) => p.contains('toggle_task_usecase.dart')),
        isTrue,
        reason:
            'Without an on-disk repository interface the guard must fail '
            'open and keep the requested usecases',
      );
    });
  });
}

/// Scaffolds a minimal entity file at the canonical v5 location
/// `lib/src/domain/entities/<snake>/<snake>.dart` so that
/// `CommonPatterns.entityImports`' filesystem resolver finds it.
Future<void> _scaffoldEntity(String outputDir, String entityName) async {
  final snake = _camelToSnake(entityName);
  final dir = Directory('$outputDir/domain/entities/$snake');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$snake.dart');
  await file.writeAsString('class $entityName {}\n');
}

/// Scaffolds a repository interface at the canonical location
/// `lib/src/domain/repositories/<snake>_repository.dart` declaring exactly
/// [methods], mimicking the output of a prior `zfa make` run.
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
  final out = input.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
  return out.startsWith('_') ? out.substring(1) : out;
}
