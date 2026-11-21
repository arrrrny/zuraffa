@Tags(['e2e'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// Regression tests for issue #2115: `zfa entity create --help` exited 2
/// with "Error: Entity name is required." because the help short-circuit
/// in `EntityCommand.execute` only looked at the FIRST argument, and
/// `_handleCreate` validated the required name before anything else.
///
/// The contract pinned here is the one #764 established for
/// `zfa entity --help` / `-h`, extended to the subcommand tail: a help
/// request anywhere in the entity argv prints the usage text, writes
/// nothing, and exits 0 — from ANY directory, project context or not.
/// Bare invocation stays a usage error (#1059), and a real subcommand
/// still goes through the pubspec guard (see
/// `entity_help_test.dart`'s regression guard).
void main() {
  setUpAll(initZfaSourceBin);

  group('entity subcommand --help (#2115)', () {
    late Directory emptyDir;

    setUp(() async {
      emptyDir = await Directory.systemTemp.createTemp('entity_help_2115_');
      // Intentionally NO pubspec.yaml: help must never require a project
      // context (#764's contract, applied to the subcommand tail).
    });

    tearDown(() async {
      await emptyDir.delete(recursive: true);
    });

    test('`zfa entity create --help` prints usage and exits 0', () async {
      final result = await runZfaSource([
        'entity',
        'create',
        '--help',
      ], workingDirectory: emptyDir.path);

      final out = '${result.stdout}${result.stderr}';
      expect(
        out,
        isNot(contains('Entity name is required')),
        reason:
            'a help request must never be answered with the '
            'name-required error (issue #2115).\n'
            'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(out, isNot(contains('No pubspec.yaml found')));
      expect(out.toLowerCase(), contains('usage'));
      expect(out, contains('create'));
      expect(
        result.exitCode,
        0,
        reason:
            'help is a successful outcome (the #764 contract); it must '
            'not exit 2.\nstdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(
        out.contains('❌'),
        isFalse,
        reason: 'help text must not use the ❌ usage-error prefix.',
      );
    });

    test('`zfa entity create -h` prints usage and exits 0', () async {
      final result = await runZfaSource([
        'entity',
        'create',
        '-h',
      ], workingDirectory: emptyDir.path);

      final out = '${result.stdout}${result.stderr}';
      expect(out, isNot(contains('Entity name is required')));
      expect(out.toLowerCase(), contains('usage'));
      expect(result.exitCode, 0);
    });

    test(
      '`zfa entity create --help` creates nothing (no files written)',
      () async {
        final before = _treeSnapshot(emptyDir);

        final result = await runZfaSource([
          'entity',
          'create',
          '--help',
        ], workingDirectory: emptyDir.path);

        expect(result.exitCode, 0);
        expect(
          _treeSnapshot(emptyDir),
          before,
          reason: 'a help request must not create or modify anything.',
        );
      },
    );

    test('`zfa entity add-field --help` prints usage and exits 0', () async {
      final result = await runZfaSource([
        'entity',
        'add-field',
        '--help',
      ], workingDirectory: emptyDir.path);

      final out = '${result.stdout}${result.stderr}';
      expect(out, isNot(contains('Entity name is required')));
      expect(out.toLowerCase(), contains('usage'));
      expect(result.exitCode, 0);
    });

    test('a real `zfa entity create` invocation keeps the pubspec guard '
        '(regression guard)', () async {
      final result = await runZfaSource([
        'entity',
        'create',
        '-n',
        'Widget',
      ], workingDirectory: emptyDir.path);

      final out = '${result.stdout}${result.stderr}';
      expect(
        out,
        anyOf(
          contains('No pubspec.yaml found'),
          contains(
            'No Flutter project found. Run from inside a project '
            'directory or use -C <path>.',
          ),
        ),
        reason:
            'the fix must not weaken the project-context guard for a '
            'real creation.\nstdout=${result.stdout}\n'
            'stderr=${result.stderr}',
      );
      expect(out, isNot(contains('USAGE')));
      expect(result.exitCode, isNot(0));
    });
  });
}

/// Every path under [root], sorted, so a test can assert that a command
/// wrote nothing.
List<String> _treeSnapshot(Directory root) {
  final paths = <String>[];
  if (!root.existsSync()) return paths;
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    paths.add(entity.path.substring(root.path.length));
  }
  paths.sort();
  return paths;
}
