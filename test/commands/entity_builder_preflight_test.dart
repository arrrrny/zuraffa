// Issue #1322 — `zfa entity create` preflights the builder dependency
// BEFORE writing the entity.
//
// Phase-0 (`zfa tdd run`) scaffolds a @Zorphy entity and a build.yaml
// registering `zorphy:zorphy` without ensuring the zorphy builder package
// is resolvable — one missing dev dependency then dead-ended the whole
// feature under misdiagnosed outcomes. The create path now runs the
// builder-dependency preflight: auto `dart pub add --dev <pkg>` (injected
// runner here, hermetic), blocking refusal when the add fails, no-op when
// the package is already resolvable.
//
// In-process through EntityCommand.execute(exitOnCompletion: false) — the
// embedded SPEC 917 mode (the make_pubspec_auto_add_test.dart pattern);
// the process-global Directory.current is switched per test and restored.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/entity_command.dart';

class _RecordingRunner {
  final List<String> invocations = [];
  final int exitCode;

  _RecordingRunner({this.exitCode = 0});

  Future<ProcessResult> call(
    String executable,
    List<String> args,
    String workingDirectory,
  ) async {
    invocations.add('$executable ${args.join(' ')}');
    return ProcessResult(1, exitCode, '', '');
  }
}

Future<String> captureOutput(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

void main() {
  late Directory dir;
  var prevCwd = Directory.current.path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zfa_1322_entity_');
    prevCwd = Directory.current.path;
    Directory.current = dir.path;
    await Directory(p.join(dir.path, 'lib', 'src')).create(recursive: true);
    await File(p.join(dir.path, 'pubspec.yaml')).writeAsString('''
name: sandbox_1322_entity
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: ^2.3.0
dev_dependencies:
  build_runner: ^2.4.0
''');
  });

  tearDown(() async {
    Directory.current = prevCwd;
    exitCode = 0;
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Windows file-lock flakiness; best-effort cleanup.
      }
    }
  });

  /// Resolves the sandbox naming exactly [packages].
  Future<void> seedPackageConfig(List<String> packages) async {
    final dartTool = Directory(p.join(dir.path, '.dart_tool'));
    await dartTool.create(recursive: true);
    final entries = packages
        .map((n) => '{"name":"$n","rootUri":"../"}')
        .join(',');
    await File(
      p.join(dartTool.path, 'package_config.json'),
    ).writeAsString('{"configVersion":2,"packages":[$entries]}');
  }

  String entityPath(String snake) =>
      p.join(dir.path, 'lib', 'src', 'domain', 'entities', snake);

  group('zfa entity create builder preflight (issue #1322)', () {
    test('blocks when the builder package is missing and the add fails: '
        'no entity written, exact fix prescribed', () async {
      await seedPackageConfig([
        'test',
        'mocktail',
        'json_serializable',
        'source_gen',
      ]);
      final runner = _RecordingRunner(exitCode: 1);
      final command = EntityCommand(pubRunner: runner.call);

      final output = await captureOutput(() async {
        // SPEC 917 embedded mode: the blocking refusal unwinds via the
        // private _EntityBail sentinel after setting the exit code.
        try {
          await command.execute([
            'create',
            '-n',
            'StreamEvent',
            '--field',
            'kind:String',
          ], exitOnCompletion: false);
        } catch (_) {
          // The bail is the expected blocking path.
        }
      });

      expect(runner.invocations, hasLength(1), reason: output);
      expect(runner.invocations.single, contains('dart pub add --dev zorphy'));
      expect(output, contains('zorphy'));
      expect(output, contains('dart pub add --dev zorphy'));
      // Blocking: the entity scaffolding never happened.
      expect(
        Directory(entityPath('stream_event')).existsSync(),
        isFalse,
        reason: output,
      );
    });

    test('no-op when zorphy is resolvable: entity created, pubspec '
        'byte-identical, no spawn', () async {
      // Every canonical builder package resolvable — the todo_planner
      // state (zorphy arrives transitively) the preflight must not touch.
      await seedPackageConfig([
        'test',
        'mocktail',
        'zorphy',
        'json_serializable',
        'source_gen',
      ]);
      final pubspecBefore = File(
        p.join(dir.path, 'pubspec.yaml'),
      ).readAsStringSync();
      final runner = _RecordingRunner();
      final command = EntityCommand(pubRunner: runner.call);

      final output = await captureOutput(() async {
        try {
          await command.execute([
            'create',
            '-n',
            'StreamEvent',
            '--field',
            'kind:String',
          ], exitOnCompletion: false);
        } catch (_) {
          fail('entity create must succeed when zorphy is resolvable');
        }
      });

      expect(runner.invocations, isEmpty, reason: output);
      expect(
        Directory(entityPath('stream_event')).existsSync(),
        isTrue,
        reason: output,
      );
      expect(
        File(p.join(dir.path, 'pubspec.yaml')).readAsStringSync(),
        pubspecBefore,
      );
    });
  });
}
