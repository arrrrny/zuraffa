// Spec 1114 — `zfa slice worktree` / `zfa slice check` CLI dispatch.
//
// INV-1: every subcommand validates its arguments and fails with usage
// text (exit 64), never a stack trace. worktree/check exit 0/1 on
// execution outcomes like the other slice subcommands.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';

import 'helpers/capture_output.dart';
import 'helpers/feature_slice_fixture.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_slice_cli_1114_');
    buildLoginProbe(workspace.path);
    await gitInitWithCommit(workspace.path);
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await Process.run('git', [
        'worktree',
        'prune',
      ], workingDirectory: workspace.path);
      try {
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            await workspace.delete(recursive: true);
            return;
          } on FileSystemException {
            if (attempt == 2) rethrow;
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        }
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  late CommandRunner<void> runner;
  late SliceCommand command;

  setUp(() {
    command = SliceCommand(projectRoot: workspace.path);
    runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
  });

  group('zfa slice worktree (dispatch)', () {
    test('opens a worktree and prints the slice root path', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'worktree', 'login']),
      );

      expect(output, contains('.zfa'));
      expect(output, contains('login'));
      expect(command.exitCode, 0, reason: output);
      expect(
        Directory(
          p.join(workspace.path, '.zfa', 'slices', 'login', 'engine'),
        ).existsSync(),
        isTrue,
      );
    });

    test('without an id fails with usage text (exit 64)', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'worktree']),
      );

      expect(output, contains('usage'), reason: 'INV-1: usage, not stack');
      expect(command.exitCode, 64);
    });

    test('an unknown feature id fails with the known ids (exit 1)', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'worktree', 'checkout']),
      );

      expect(output, contains('checkout'));
      expect(output, contains('login'));
      expect(command.exitCode, 1);
    });
  });

  group('zfa slice check (dispatch)', () {
    test('a composed slice checks green (exit 0)', () async {
      await captureOutput(() => runner.run(['slice', 'worktree', 'login']));

      final output = await captureOutput(
        () => runner.run(['slice', 'check', 'login']),
      );

      expect(command.exitCode, 0, reason: output);
      expect(output.toLowerCase(), contains('compliant'));
    });

    test('a slice with files outside it fails (exit 1)', () async {
      await captureOutput(() => runner.run(['slice', 'worktree', 'login']));

      writeFile(
        p.join(workspace.path, '.zfa', 'slices', 'login'),
        'engine/entities/hacker/hacker.dart',
        'class Hacker {}\n',
      );

      final output = await captureOutput(
        () => runner.run(['slice', 'check', 'login']),
      );

      expect(command.exitCode, 1, reason: output);
      expect(output, contains('hacker'));
      expect(output.toLowerCase(), contains('outside'));
    });

    test('without an id fails with usage text (exit 64)', () async {
      final output = await captureOutput(() => runner.run(['slice', 'check']));

      expect(output, contains('usage'), reason: 'INV-1: usage, not stack');
      expect(command.exitCode, 64);
    });
  });

  group('usage surface', () {
    test('the slice usage lists worktree and check', () async {
      final output = await captureOutput(() => runner.run(['slice', '--help']));
      expect(output, contains('worktree'));
      expect(output, contains('check'));
    });

    test('focused help exists for worktree and check', () async {
      final wtHelp = await captureOutput(
        () => runner.run(['slice', 'worktree', '--help']),
      );
      expect(wtHelp, contains('zfa slice worktree'));

      final checkHelp = await captureOutput(
        () => runner.run(['slice', 'check', '--help']),
      );
      expect(checkHelp, contains('zfa slice check'));
    });
  });
}
