// Issue #1506 — `dart format` in a fresh clone emits repeated
// "Package resolution error" warnings (analysis_options.yaml includes
// package:lints/recommended.yaml, unresolvable without a package
// config) and rewrites hundreds of unrelated files (868 in the
// reproduction on Dart 3.13.2).
//
// FormatRunner is the format path for the generation commands (the TDD
// refactor pass registry runs its own `dart format lib/` and is tracked
// separately): it verifies package resolution first, enforces
// `dart pub get --no-example` when missing, and never spawns the
// formatter without resolution — the per-file warning spam becomes
// unreachable. Whole-tree scopes (`.`, `..`, the package root) are
// rejected before any process is spawned.
//
// Hermetic throughout: the process runner is injected (the
// PubspecProcessRunner typedef convention, pubspec_auto_add.dart:36)
// and resolution is a real `.dart_tool/package_config.json` fixture in
// a temp project (the entity_builder_preflight_test.dart pattern).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/format/format_runner.dart';

class _RecordingRunner {
  final List<String> invocations = [];
  final int pubGetExitCode;

  /// Canned `dart format` stdout, so the result's captured output can be
  /// asserted (the `inheritStdio` summary the CLI now carries itself).
  final String formatStdout;

  _RecordingRunner({this.pubGetExitCode = 0, this.formatStdout = ''});

  Future<ProcessResult> call(
    String executable,
    List<String> args,
    String workingDirectory,
  ) async {
    invocations.add('$executable ${args.join(' ')}');
    if (args.isNotEmpty && args.first == 'pub') {
      if (pubGetExitCode != 0) {
        return ProcessResult(1, pubGetExitCode, '', 'resolution failed');
      }
      // Simulate what a real successful `dart pub get` does: write the
      // package config the runner re-verifies before formatting.
      final dartTool = Directory(p.join(workingDirectory, '.dart_tool'));
      if (!dartTool.existsSync()) dartTool.createSync(recursive: true);
      File(
        p.join(dartTool.path, 'package_config.json'),
      ).writeAsStringSync('{"configVersion":2,"packages":[]}');
      return ProcessResult(1, 0, '', '');
    }
    return ProcessResult(1, 0, formatStdout, '');
  }
}

Future<Directory> _tempProject() async {
  final dir = await Directory.systemTemp.createTemp('zfa_1506_format_');
  await File(p.join(dir.path, 'pubspec.yaml')).writeAsString('''
name: sandbox_1506_format
environment:
  sdk: ^3.11.0
''');
  return dir;
}

Future<void> _seedPackageConfig(Directory dir) async {
  final dartTool = Directory(p.join(dir.path, '.dart_tool'));
  await dartTool.create(recursive: true);
  await File(
    p.join(dartTool.path, 'package_config.json'),
  ).writeAsString('{"configVersion":2,"packages":[]}');
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await _tempProject();
  });

  tearDown(() async {
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Windows file-lock flakiness; best-effort cleanup.
      }
    }
  });

  group('FormatRunner fresh-clone robustness (issue #1506)', () {
    test('U1: empty scope is a no-op — no process spawned', () async {
      final runner = _RecordingRunner();
      final format = FormatRunner(processRunner: runner.call);

      final result = await format.formatPaths([], workingDirectory: dir.path);

      expect(runner.invocations, isEmpty);
      expect(result.formatRan, isFalse);
      expect(result.pubGetRan, isFalse);
      expect(result.skipped, isTrue);
    });

    test('U2: tree-wide scope rejected before ANY process spawns', () async {
      // `.` / `./` are the literal tree-wide scopes; `..` and the
      // absolute package root (and its parent) resolve to the same whole
      // tree and are rejected by the resolved-path guard.
      for (final scope in ['.', './', '..', p.dirname(dir.path), dir.path]) {
        final runner = _RecordingRunner();
        final format = FormatRunner(processRunner: runner.call);

        await expectLater(
          format.formatPaths([scope], workingDirectory: dir.path),
          throwsArgumentError,
        );
        expect(
          runner.invocations,
          isEmpty,
          reason: 'a tree-wide format must never reach a process',
        );
      }
    });

    test('U3: missing resolution — pub get enforced BEFORE format', () async {
      final runner = _RecordingRunner();
      final format = FormatRunner(processRunner: runner.call);

      final result = await format.formatPaths([
        'lib/src/domain/entities',
      ], workingDirectory: dir.path);

      expect(
        runner.invocations,
        hasLength(2),
        reason: runner.invocations.join(' | '),
      );
      expect(runner.invocations.first, 'dart pub get --no-example');
      expect(runner.invocations.last, 'dart format lib/src/domain/entities');
      expect(result.pubGetRan, isTrue);
      expect(result.formatRan, isTrue);
      expect(result.skipped, isFalse);
      expect(result.warning, isNull);
    });

    test('U4: unresolvable — formatter NEVER spawned, one warning', () async {
      final runner = _RecordingRunner(pubGetExitCode: 1);
      final format = FormatRunner(processRunner: runner.call);

      final result = await format.formatPaths([
        'lib/src/domain/entities',
      ], workingDirectory: dir.path);

      expect(
        runner.invocations,
        hasLength(1),
        reason:
            'only the pub get may run — no dart format without '
            'resolution (the per-file warning-spam path is unreachable)',
      );
      expect(runner.invocations.single, 'dart pub get --no-example');
      expect(result.formatRan, isFalse);
      expect(result.skipped, isTrue);
      expect(result.warning, isNotNull);
      expect(result.warning, contains('pub get'));
      // One actionable remediation, not per-file spam: the hint covers
      // Flutter hosts whose only working resolution is flutter pub get.
      expect(result.warning, contains('flutter pub get'));
      // The formatter never ran, so there is no captured output.
      expect(result.output, isNull);
    });

    test('U5: resolution present — format only, no pub get', () async {
      await _seedPackageConfig(dir);
      final runner = _RecordingRunner(
        formatStdout: 'Formatted 1 file (0 changed)',
      );
      final format = FormatRunner(processRunner: runner.call);

      final result = await format.formatPaths([
        'lib/src/domain/entities',
      ], workingDirectory: dir.path);

      expect(
        runner.invocations,
        hasLength(1),
        reason: runner.invocations.join(' | '),
      );
      expect(runner.invocations.single, 'dart format lib/src/domain/entities');
      expect(result.pubGetRan, isFalse);
      expect(result.formatRan, isTrue);
      expect(result.warning, isNull);
      // The `Formatted N files (M changed)` summary survives the move off
      // inheritStdio instead of being silently discarded.
      expect(result.output, 'Formatted 1 file (0 changed)');
    });

    test(
      'U6: padded scope is trimmed/normalized, never a whole-tree element',
      () async {
        await _seedPackageConfig(dir);
        final runner = _RecordingRunner();
        final format = FormatRunner(processRunner: runner.call);

        await format.formatPaths([
          ' lib/src/domain/entities ',
        ], workingDirectory: dir.path);

        // Trimmed and normalized before the process sees it — the padded
        // original would make the formatter reject the path.
        expect(
          runner.invocations.single,
          'dart format lib/src/domain/entities',
        );
        final args = runner.invocations.single
            .split('..') //
            .first
            .split(' ')
            .skip(1)
            .toList();
        expect(args, contains('lib/src/domain/entities'));
        for (final forbidden in ['.', './', 'lib', 'test']) {
          expect(args, isNot(contains(forbidden)));
        }
      },
    );
  });
}
