@Tags(['regression'])
library;

// Regression test for issue #1132 (EPIC 1 honesty sweep).
//
// `zfa slice` with no arguments printed the usage block and returned
// WITHOUT setting `exitCode` — the process exited 0 for a command that
// took no subcommand. That is the "lying-success" pattern the EPIC 1
// fleet exit-code sweep was supposed to eliminate; slice_command.dart
// was the one command the #1239 sweep missed (its bare-branch returned
// without flagging a usage error).
//
// Fix: bare `zfa slice` exits the CANONICAL 2 (SPEC 917; legacy 64
// retired). Explicit help (`zfa slice --help`, `zfa slice -h`) keeps
// exiting 0 — help is a successful outcome.
//
// The in-process unit-level counterpart is in
// test/plugins/slice/slice_command_test.dart (U65/U66 + the new
// bare-slice assertion). This regression test pins the SUBPROCESS-level
// contract so the lying-success pattern cannot return through any
// future change to the dispatch path.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  group('#1132 — zfa slice bare invocation must exit 2 (usage), not 0', () {
    late Directory workspace;

    Future<ProcessResult> runZfa(List<String> args) {
      return runZfaSource([...args], workingDirectory: workspace.path);
    }

    setUp(() async {
      await initZfaSourceBin();
      workspace = await Directory.systemTemp.createTemp('issue_1132_slice_');
      // The slice command's dependency check scans pubspec.yaml for
      // the strings `zorphy_annotation:` and `build_runner:`. The strings
      // are enough — the usage-error paths under test never run
      // `dart pub get`.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_1132_slice_test_app
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

    test('bare `zfa slice` exits 2 with usage on stdout (no subcommand = usage '
        'error)', () async {
      final result = await runZfa(['slice']);

      expect(
        result.exitCode,
        equals(2),
        reason:
            'zfa slice with no subcommand is a usage error and must exit '
            'the CANONICAL 2 (SPEC 917; legacy 64 retired), not 0 '
            '(issue #1132 EPIC 1 honesty sweep: lying-success)',
      );
      expect(
        result.stdout,
        contains('usage: zfa slice SUBCOMMAND'),
        reason:
            'the usage block must be emitted (the runner needs to '
            'know which subcommand to invoke)',
      );
    });

    test('explicit `zfa slice --help` still exits 0 (help is a successful '
        'outcome)', () async {
      final result = await runZfa(['slice', '--help']);

      expect(
        result.exitCode,
        equals(0),
        reason:
            'an explicit help request is a successful outcome and must '
            'keep exiting 0 — only the BARE invocation is a usage error',
      );
      expect(result.stdout, contains('usage: zfa slice SUBCOMMAND'));
    });

    test('explicit `zfa slice -h` still exits 0 (short help is also a '
        'successful outcome)', () async {
      final result = await runZfa(['slice', '-h']);

      expect(
        result.exitCode,
        equals(0),
        reason: 'an explicit short-help request is also a successful outcome',
      );
      expect(result.stdout, contains('usage: zfa slice SUBCOMMAND'));
    });

    test('`zfa slice teleport` (unknown subcommand) exits 2 (usage)', () async {
      final result = await runZfa(['slice', 'teleport']);

      expect(
        result.exitCode,
        equals(2),
        reason:
            'an unknown subcommand is a usage error and must exit the '
            'CANONICAL 2, not 0 (issue #1132 EPIC 1 honesty sweep)',
      );
      expect(result.stdout, contains('Unknown slice subcommand'));
    });

    test('`zfa slice cut <name>` without --entry exits 2 (usage)', () async {
      final result = await runZfa(['slice', 'cut', 'profile_feature']);

      expect(
        result.exitCode,
        equals(2),
        reason:
            'cut without --entry is a usage error and must exit the '
            'CANONICAL 2, not 0 (U66 / issue #1132)',
      );
      expect(result.stdout, contains('Missing --entry'));
    });

    test('`zfa slice merge` without a name exits 2 (usage)', () async {
      final result = await runZfa(['slice', 'merge']);

      expect(
        result.exitCode,
        equals(2),
        reason:
            'merge without a slice name is a usage error and must exit '
            'the CANONICAL 2, not 0 (issue #1132)',
      );
      expect(result.stdout, contains('Missing slice name'));
    });
  });
}
