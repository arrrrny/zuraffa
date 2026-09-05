// Spec #972 — close the #921 fail-open hole (FR-4).
//
// When the source interface is ABSENT at usecase-generation time (the
// same-plan case: the service plugin runs after the usecase plugin, or
// the repository plugin is muted by --use-service), the guard currently
// fails open and the generated usecases reference methods nobody
// declared — the build breaks later with no hint why. The fix records
// the requested method set as an interface expectation in the plan, and
// a `zfa make` post-pass verifies the responsible plugin (repository or
// service) actually declared them; a mismatch fails the make run with
// exit 1 and a `--> fix: zfa repository create <E> --methods=...` line.
//
// Tested both ways:
//   * negative — repository muted by --use-service: interface never
//     created → make fails with the fix line.
//   * positive — service-in-plan with matching --methods: interface
//     declared → make succeeds.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory workspace;
  late CliRunner runner;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_usecase_exp_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: usecase_expectation_test
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

  test('FR-4 negative: repository muted by --use-service — same-plan misfire '
      'FAILS the make run with the fix line', () async {
    await _scaffoldEntity(workspace.path, 'Task');

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'make',
      'Task',
      'repository',
      'usecase',
      '--use-service',
    ]);

    expect(
      output,
      contains('fix: zfa repository create Task'),
      reason:
          'the same-plan misfire must name the exact repair command:\n'
          '$output',
    );
    expect(
      exitCode,
      1,
      reason: 'a misfired make run must not look successful:\n$output',
    );
    expect(
      output,
      isNot(contains('✅ Done.')),
      reason: 'a failed run must not print success',
    );
  });

  test(
    'FR-4 positive: service-in-plan declares the requested methods — '
    'make succeeds and the usecases compile against a real interface',
    () async {
      await _scaffoldEntity(workspace.path, 'Chat');

      final output = await runner.runCapturing([
        '-C',
        workspace.path,
        'make',
        'Chat',
        'service',
        'usecase',
        '--service=ChatService',
        '--methods=get,update',
      ]);

      expect(
        output,
        isNot(contains('fix: zfa')),
        reason: 'no expectation mismatch:\n$output',
      );
      expect(
        exitCode,
        0,
        reason: 'declared interface must satisfy the expectation:\n$output',
      );

      // The service interface the usecases call must exist and declare the
      // methods the usecases invoke.
      final serviceFile = File(
        p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'services',
          'chat',
          'chat_service.dart',
        ),
      );
      expect(serviceFile.existsSync(), isTrue, reason: 'service interface');
      final serviceSource = await serviceFile.readAsString();
      expect(serviceSource, contains('get('));
      expect(serviceSource, contains('update('));

      // And the usecases that reference it exist.
      final usecaseDir = Directory(
        p.join(workspace.path, 'lib', 'src', 'domain', 'usecases', 'chat'),
      );
      final usecaseFiles = usecaseDir.existsSync()
          ? usecaseDir.listSync().map((e) => p.basename(e.path)).toList()
          : <String>[];
      expect(
        usecaseFiles.any((f) => f.contains('get_chat_usecase.dart')),
        isTrue,
        reason: 'usecase files: $usecaseFiles',
      );
      expect(
        usecaseFiles.any((f) => f.contains('update_chat_usecase.dart')),
        isTrue,
        reason: 'usecase files: $usecaseFiles',
      );
    },
  );

  test('FR-4 scope: repository NOT in plan (usecase-only run) keeps the '
      'pre-existing fail-open behavior — no post-pass failure', () async {
    await _scaffoldEntity(workspace.path, 'Solo');

    final output = await runner.runCapturing([
      '-C',
      workspace.path,
      'make',
      'Solo',
      'usecase',
    ]);

    expect(
      output,
      isNot(contains('fix: zfa repository create')),
      reason: 'no responsible plugin in plan — nothing to verify:\n$output',
    );
    expect(
      exitCode,
      0,
      reason: 'usecase-only runs keep the fail-open contract:\n$output',
    );
  });
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
