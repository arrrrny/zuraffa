// Issue #1506 — the entity generation flow formatted the ENTIRE package
// tree (`dart format .`): in a fresh clone (no package config) that is
// the worst-case invocation from the issue report — per-file
// "Package resolution error" warning spam plus a tree-wide rewrite of
// every file under the working directory.
//
// After the fix, EntityCommand formats through FormatRunner, scoped to
// the generated entity output tree (`lib/src/domain/entities`) with the
// pub-get enforcement in front. In-process through
// EntityCommand.execute(exitOnCompletion: false) — the embedded SPEC 917
// mode (the entity_builder_preflight_test.dart #1322 pattern); the
// process-global Directory.current is switched per test and restored.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/entity_command.dart';
import 'package:zuraffa/src/core/format/format_runner.dart';

class _RecordingFormatRunner {
  _RecordingFormatRunner([List<String>? recorder])
    : invocations = recorder ?? <String>[];

  /// The recorded process invocations. U8 shares one list with the pub
  /// runner so cross-seam call order is observable.
  final List<String> invocations;

  /// `late final` so the initializer can access [invocations] (field
  /// initializers cannot read `this`).
  late final FormatRunner runner = FormatRunner(processRunner: _record);

  FormatRunner get formatRunner => runner;

  Future<ProcessResult> _record(
    String executable,
    List<String> args,
    String workingDirectory,
  ) async {
    invocations.add('$executable ${args.join(' ')}');
    if (args.isNotEmpty && args.first == 'pub') {
      // Simulate what a real successful `dart pub get` does: write the
      // package config the runner re-verifies before formatting.
      final dartTool = Directory(p.join(workingDirectory, '.dart_tool'));
      if (!dartTool.existsSync()) dartTool.createSync(recursive: true);
      File(
        p.join(dartTool.path, 'package_config.json'),
      ).writeAsStringSync('{"configVersion":2,"packages":[]}');
    }
    return ProcessResult(1, 0, '', '');
  }
}

class _RecordingPubRunner {
  _RecordingPubRunner([List<String>? recorder])
    : invocations = recorder ?? <String>[];

  final List<String> invocations;

  Future<ProcessResult> call(
    String executable,
    List<String> args,
    String workingDirectory,
  ) async {
    invocations.add('$executable ${args.join(' ')}');
    return ProcessResult(1, 0, '', '');
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
    dir = await Directory.systemTemp.createTemp('zfa_1506_entity_');
    prevCwd = Directory.current.path;
    Directory.current = dir.path;
    await Directory(p.join(dir.path, 'lib', 'src')).create(recursive: true);
    await File(p.join(dir.path, 'pubspec.yaml')).writeAsString('''
name: sandbox_1506_entity
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

  /// Resolves the sandbox naming exactly [packages] — the seeded
  /// package config also satisfies the builder-dependency preflight.
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

  group('zfa entity format scope (issue #1506)', () {
    test(
      'U7: --dart-format formats the entity tree only — never "."',
      () async {
        await seedPackageConfig([
          'test',
          'mocktail',
          'zorphy',
          'json_serializable',
          'source_gen',
        ]);
        final formatRunner = _RecordingFormatRunner();
        final command = EntityCommand(formatRunner: formatRunner.formatRunner);

        final output = await captureOutput(() async {
          await command.execute([
            'create',
            '-n',
            'StreamEvent',
            '--field',
            'kind:String',
            '--dart-format',
          ], exitOnCompletion: false);
        });

        expect(
          Directory(
            p.join(
              dir.path,
              'lib',
              'src',
              'domain',
              'entities',
              'stream_event',
            ),
          ).existsSync(),
          isTrue,
          reason: output,
        );
        expect(formatRunner.invocations, hasLength(1), reason: output);
        expect(
          formatRunner.invocations.single,
          'dart format lib/src/domain/entities',
        );
      },
    );

    test(
      'U8: without resolution, pub get precedes the scoped format',
      () async {
        // One shared log across both seams: concatenating two separate
        // lists could never observe the two runners' real interleaving.
        final calls = <String>[];
        final pubRunner = _RecordingPubRunner(calls);
        final formatRunner = _RecordingFormatRunner(calls);
        final command = EntityCommand(
          pubRunner: pubRunner.call,
          formatRunner: formatRunner.formatRunner,
        );

        final output = await captureOutput(() async {
          await command.execute([
            'create',
            '-n',
            'StreamEvent',
            '--field',
            'kind:String',
            '--dart-format',
          ], exitOnCompletion: false);
        });

        final all = calls;
        expect(
          all,
          contains('dart pub get --no-example'),
          reason:
              'the enforcement must run pub get (via either runner): '
              '${all.join(' | ')}',
        );
        final pubGetIndex = all.indexOf('dart pub get --no-example');
        final formatIndex = all.indexWhere((i) => i.startsWith('dart format'));
        expect(formatIndex, greaterThan(pubGetIndex), reason: all.join(' | '));
        expect(
          all[formatIndex],
          'dart format lib/src/domain/entities',
          reason: output,
        );
      },
    );
  });
}
