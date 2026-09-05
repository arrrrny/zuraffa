// Spec #972 FR-5 — toggle leaves the silent default vocabulary.
//
// `usecase_plugin.dart` silently defaulted every entity to
// ['get', 'update', 'toggle']. Toggle has no universal semantics: an
// entity whose repository was never asked for toggle gets a
// ToggleXUseCase calling a method that does not exist (#921's original
// misfire). From now on toggle is generated ONLY when explicitly
// requested via --methods (and only when the guard can see it declared
// on the source interface).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory workspace;
  late CliRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_usecase_toggle_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: usecase_toggle_test
environment:
  sdk: ^3.11.0
''');
    runner = CliRunner(exitOnCompletion: false);
    exitCode = 0;
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  test('no entity gets toggle without explicit request — the silent default '
      'is gone', () async {
    await _scaffoldEntity(workspace.path, 'Product');

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'usecase',
      'create',
      'Product',
      '--json',
    ]);

    // The envelope's requested set is the honest default: get, update.
    final envelope = jsonDecode(output.trim()) as Map<String, dynamic>;
    final methods = (envelope['methods'] as List)
        .cast<Map<String, dynamic>>()
        .map((m) => m['name'] as String)
        .toList();
    expect(methods, ['get', 'update'], reason: 'default methods: $methods');

    // And no toggle usecase file was emitted.
    final usecaseDir = Directory(
      p.join(workspace.path, 'lib', 'src', 'domain', 'usecases', 'product'),
    );
    final files = usecaseDir.existsSync()
        ? usecaseDir.listSync().map((e) => p.basename(e.path)).toList()
        : <String>[];
    expect(
      files.any((f) => f.contains('toggle')),
      isFalse,
      reason: 'toggle must not be generated silently: $files',
    );
    expect(files.any((f) => f.contains('get_product_usecase.dart')), isTrue);
    expect(files.any((f) => f.contains('update_product_usecase.dart')), isTrue);
  });

  test('make flow: the default method set requests no toggle — even though '
      'the repository interface (default vocabulary) declares it', () async {
    await _scaffoldEntity(workspace.path, 'Task');

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'make',
      'Task',
      'repository',
      'usecase',
    ]);

    expect(exitCode, 0, reason: 'the make run itself must succeed:\n$output');

    // The repository interface exists (repository plugin defaults keep
    // their own vocabulary — toggle included)...
    final repoInterface = File(
      p.join(
        workspace.path,
        'lib',
        'src',
        'domain',
        'repositories',
        'task_repository.dart',
      ),
    );
    expect(repoInterface.existsSync(), isTrue);
    expect(
      repoInterface.readAsStringSync(),
      contains('toggle('),
      reason:
          'the repository interface declares toggle (its own default '
          'vocabulary is out of this spec\'s scope)',
    );

    // ...but the usecase plugin must not silently request a toggle
    // usecase against it.
    final usecaseDir = Directory(
      p.join(workspace.path, 'lib', 'src', 'domain', 'usecases', 'task'),
    );
    final files = usecaseDir.existsSync()
        ? usecaseDir.listSync().map((e) => p.basename(e.path)).toList()
        : <String>[];
    expect(
      files.any((f) => f.contains('toggle')),
      isFalse,
      reason: 'make without --methods must not emit a toggle usecase: $files',
    );
    expect(files.any((f) => f.contains('get_task_usecase.dart')), isTrue);
    expect(files.any((f) => f.contains('update_task_usecase.dart')), isTrue);
  });

  test(
    'explicit --methods=get,toggle still generates toggle (guard fails '
    'open with no on-disk interface — the explicit request is honored)',
    () async {
      await _scaffoldEntity(workspace.path, 'Task');

      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'usecase',
        'create',
        'Task',
        '--methods=get,toggle',
        '--json',
      ]);

      final envelope = jsonDecode(output.trim()) as Map<String, dynamic>;
      final methods = (envelope['methods'] as List)
          .cast<Map<String, dynamic>>()
          .map((m) => m['name'] as String)
          .toList();
      expect(methods, containsAll(['get', 'toggle']));

      final usecaseDir = Directory(
        p.join(workspace.path, 'lib', 'src', 'domain', 'usecases', 'task'),
      );
      final files = usecaseDir.existsSync()
          ? usecaseDir.listSync().map((e) => p.basename(e.path)).toList()
          : <String>[];
      expect(
        files.any((f) => f.contains('toggle_task_usecase.dart')),
        isTrue,
        reason: 'explicit request must be honored: $files',
      );
    },
  );
}

Future<void> _scaffoldEntity(String projectRoot, String entityName) async {
  final snake = _camelToSnake(entityName);
  final dir = Directory(
    p.join(projectRoot, 'lib', 'src', 'domain', 'entities', snake),
  );
  await dir.create(recursive: true);
  await File(p.join(dir.path, '$snake.dart')).writeAsString('''
class $entityName {
  final String id;

  const $entityName({required this.id});
}
''');
}

String _camelToSnake(String input) => input
    .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
    .replaceFirst(RegExp(r'^_'), '');
