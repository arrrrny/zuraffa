import 'dart:io';

import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// Regression tests for issue #764: `zfa entity --help` outside a project
/// root exited 1 with "No pubspec.yaml found" because the pubspec dependency
/// guard in EntityCommand.execute ran before the help path. `--help` must be
/// reachable from any directory.
///
/// These tests drive the real CLI as a subprocess (via [runZfaSource]) so the
/// command's own `exit(N)` behavior cannot kill the test harness — and so the
/// exact user-facing contract (output + exit code) is what gets asserted.
void main() {
  setUpAll(initZfaSourceBin);

  group('entity --help outside a project (#764)', () {
    late Directory emptyDir;

    setUp(() async {
      emptyDir = await Directory.systemTemp.createTemp('entity_help_');
      // Intentionally NO pubspec.yaml: the pubspec guard must not fire for
      // the help path.
    });

    tearDown(() async {
      await emptyDir.delete(recursive: true);
    });

    test(
      '--help prints usage and exits 0 instead of the pubspec error',
      () async {
        final result = await runZfaSource([
          'entity',
          '--help',
        ], workingDirectory: emptyDir.path);

        final out = '${result.stdout}${result.stderr}';
        expect(out, isNot(contains('No pubspec.yaml found')));
        expect(out.toLowerCase(), contains('usage'));
        expect(out, contains('create'));
        expect(out, contains('add-field'));
        expect(result.exitCode, 0);
      },
    );

    test('-h prints usage and exits 0 instead of the pubspec error', () async {
      final result = await runZfaSource([
        'entity',
        '-h',
      ], workingDirectory: emptyDir.path);

      final out = '${result.stdout}${result.stderr}';
      expect(out, isNot(contains('No pubspec.yaml found')));
      expect(out.toLowerCase(), contains('usage'));
      expect(result.exitCode, 0);
    });

    test(
      'entity operations keep the pubspec guard (regression guard)',
      () async {
        final result = await runZfaSource([
          'entity',
          'list',
        ], workingDirectory: emptyDir.path);

        // FR-2: operations are still blocked outside a project, with the
        // actionable message and a non-zero exit — the fix must not weaken
        // the guard.
        final out = '${result.stdout}${result.stderr}';
        expect(out, contains('No pubspec.yaml found'));
        expect(result.exitCode, isNot(0));
      },
    );
  });
}
