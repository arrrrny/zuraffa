@Tags(['regression'])
library;

// Regression test for issue #1059.
//
// `zfa entity cli` with no arguments printed its usage line and returned
// WITHOUT setting `exitCode` — the process exited 0 for a command that did
// nothing. That is the "lying-success" pattern the #995 fleet exit-code sweep
// (PR #1039) was supposed to eliminate; `_handleCli()` in entity_command.dart
// was the one command the sweep missed (entity_command.dart is not a
// PluginCommand subclass, so it never got the reportSubcommandUsage() guard).
//
// Fix: usage errors go to stderr with `exitCode = 64` (EX_USAGE), matching
// the #1039 convention. The sweep also fixed the same lie on the sibling
// paths of the entity subcommand family:
//   - bare `zfa entity` printed help and exited 0 -> now exits 64
//   - unknown subcommand with exitOnCompletion=false fell through with
//     exitCode 0 -> now propagates exitCode = 1
// while legitimate help (`zfa entity --help`) still exits 0.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  group('#1059 — zfa entity cli bare invocation must exit 64, not 0', () {
    late Directory workspace;

    Future<ProcessResult> runZfa(List<String> args) {
      return runZfaSource([...args], workingDirectory: workspace.path);
    }

    setUp(() async {
      await initZfaSourceBin();
      workspace = await Directory.systemTemp.createTemp('issue_1059_');
      // The entity command's dependency check scans pubspec.yaml for the
      // strings `zorphy_annotation:` and `build_runner:`. The strings are
      // enough — the usage-error paths under test never run `dart pub get`.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_1059_test_app
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  zorphy_annotation:
dev_dependencies:
  build_runner:
''');
    });

    tearDown(() async {
      try {
        await workspace.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup; a leaked temp dir must not fail the run.
      }
    });

    test('bare `zfa entity cli` exits 64 with usage on stderr', () async {
      final result = await runZfa(['entity', 'cli']);

      expect(
        result.exitCode,
        equals(64),
        reason:
            'zfa entity cli with no EntityName is a usage error and must '
            'exit 64 (EX_USAGE), not 0 (issue #1059: lying-success)',
      );
      expect(
        result.stderr,
        contains('Usage: zfa entity cli <EntityName>'),
        reason: 'the usage line must go to stderr, not stdout',
      );
      expect(
        result.stdout,
        isNot(contains('Usage: zfa entity cli <EntityName>')),
        reason: 'usage must not be duplicated on stdout',
      );
    });

    test(
      'bare `zfa entity` exits 64 (same lie, entity family sweep)',
      () async {
        final result = await runZfa(['entity']);

        expect(
          result.exitCode,
          equals(64),
          reason:
              'bare zfa entity prints help and runs no subcommand — a usage '
              'error that used to exit 0 (issue #1059 sweep)',
        );
      },
    );

    test('unknown entity subcommand exits non-zero', () async {
      final result = await runZfa(['entity', 'definitely-not-a-subcommand']);

      expect(
        result.exitCode,
        isNot(equals(0)),
        reason:
            'an unknown subcommand is an error; it must never exit 0 '
            '(issue #1059 sweep)',
      );
      expect(result.stdout, contains('Unknown subcommand'));
    });

    test(
      'explicit `zfa entity --help` still exits 0 (help is not an error)',
      () async {
        final result = await runZfa(['entity', '--help']);

        expect(
          result.exitCode,
          equals(0),
          reason:
              'an explicit help request is a successful outcome and must keep '
              'exiting 0 — only the BARE invocation is a usage error',
        );
      },
    );
  });
}
