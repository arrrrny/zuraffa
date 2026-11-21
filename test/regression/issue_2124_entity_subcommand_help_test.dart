@Tags(['regression', 'slow', 'e2e'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// Regression tests for issue #2124: `zfa entity create --help` required an
/// entity name before honoring the help request, so the help path was
/// unreachable without a throwaway `-n` value (exit 2).
///
/// The entity subcommands parse their args manually and validate the required
/// entity name before any help check, unlike the `args`-package commands
/// (e.g. `zfa make --help`) which short-circuit on `--help` automatically.
/// Help must short-circuit command-specific required-argument validation for
/// every entity subcommand.
///
/// These tests drive the real CLI as a subprocess (via [runZfaSource]) so the
/// command's own `exit(N)` behavior cannot kill the test harness — and so the
/// exact user-facing contract (output + exit code) is what gets asserted.
void main() {
  setUpAll(initZfaSourceBin);

  group('entity subcommand --help short-circuits required args (#2124)', () {
    late Directory emptyDir;

    setUp(() async {
      emptyDir = await Directory.systemTemp.createTemp('entity_help_2124_');
      // Intentionally NO pubspec.yaml: help must be reachable without a
      // project context, exactly like the #764 `zfa entity --help` contract.
    });

    tearDown(() async {
      await emptyDir.delete(recursive: true);
    });

    test('--help on entity create prints usage and exits 0', () async {
      final result = await runZfaSource([
        'entity',
        'create',
        '--help',
      ], workingDirectory: emptyDir.path);

      final out = '${result.stdout}${result.stderr}';
      expect(out, isNot(contains('Entity name is required')));
      expect(out.toLowerCase(), contains('usage'));
      expect(out, contains('create'));
      expect(result.exitCode, 0);
    });

    test('-h on entity create prints usage and exits 0', () async {
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
      '--help before the name still works (help wins over -n order)',
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '--help',
          '-n',
          'Ignored',
        ], workingDirectory: emptyDir.path);

        final out = '${result.stdout}${result.stderr}';
        expect(out, isNot(contains('Entity name is required')));
        expect(out.toLowerCase(), contains('usage'));
        expect(result.exitCode, 0);
      },
    );

    test(
      'entity create without --help still requires the name (guard intact)',
      () async {
        // Run inside a minimal project so the generation-root and dependency
        // guards pass and execution reaches the name-required validation —
        // the exact path the fix must preserve.
        final projectDir = await Directory.systemTemp.createTemp(
          'entity_guard_2124_',
        );
        await File('${projectDir.path}/pubspec.yaml').writeAsString('''
name: guard_fixture
environment:
  sdk: ^3.0.0
dependencies:
  zorphy_annotation: ^1.0.0
dev_dependencies:
  build_runner: ^2.0.0
''');
        try {
          final result = await runZfaSource([
            'entity',
            'create',
          ], workingDirectory: projectDir.path);

          final out = '${result.stdout}${result.stderr}';
          expect(out, contains('Entity name is required'));
          expect(result.exitCode, isNot(0));
        } finally {
          await projectDir.delete(recursive: true);
        }
      },
    );

    test(
      'zfa make --help prints usage and exits 0 (companion command in #2124)',
      () async {
        final result = await runZfaSource([
          'make',
          '--help',
        ], workingDirectory: emptyDir.path);

        final out = '${result.stdout}${result.stderr}';
        expect(out.toLowerCase(), contains('usage'));
        expect(result.exitCode, 0);
      },
    );
  });
}
