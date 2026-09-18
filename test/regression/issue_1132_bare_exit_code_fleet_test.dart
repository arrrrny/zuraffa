@Tags(['regression', 'slow', 'e2e'])
library;

// SPEC 1132 / EPIC 1 lane 1 — the SUBPROCESS-level fleet pins.
//
// The in-process sweep (test/commands/exit_code_sweep_1132_test.dart)
// pins the five commands whose lying arms are `return`-based. This suite
// pins the whole six-command set at the process boundary — including the
// arms that today hard-call `exit()` (config bare/unknown/set, plugin
// enable without an id, plugin unknown): a hard exit kills an in-process
// isolate, so the process boundary is the only honest place to pin them
// pre-fix. Post-fix the same assertions prove the process exit codes.
//
// Model: test/regression/issue_1132_slice_bare_exit_code_test.dart
// (the #1296 slice pin — the fleet exit-code sweep's regression tier).
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  group('#1132 — bare/unknown invocations exit 2 (SPEC 917 usage)', () {
    late Directory workspace;

    Future<ProcessResult> runZfa(List<String> args) {
      return runZfaSource(args, workingDirectory: workspace.path);
    }

    setUp(() async {
      await initZfaSourceBin();
      workspace = await Directory.systemTemp.createTemp('issue_1132_fleet_');
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_1132_fleet_fixture
environment:
  sdk: ^3.11.0
''');
    });

    tearDown(() async {
      try {
        await workspace.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup.
      }
    });

    void expectUsageError(ProcessResult result, String usageMark) {
      expect(
        result.exitCode,
        equals(2),
        reason:
            'SPEC 917: the invocation could not run — usage error exits '
            'canonical 2, never 0 (EPIC 1 honesty sweep). '
            'stdout/stderr:\n${combinedOutput(result)}',
      );
      expect(
        combinedOutput(result),
        contains(usageMark),
        reason: 'the usage block must be emitted for the runner',
      );
    }

    test('bare `zfa cli` exits 2', () async {
      final result = await runZfa(['cli']);
      expectUsageError(result, 'Usage: zfa cli');
    });

    test('bare `zfa benchmark` exits 2', () async {
      final result = await runZfa(['benchmark']);
      expectUsageError(result, 'usage: zfa benchmark SUBCOMMAND');
    });

    test('bare `zfa bone` exits 2', () async {
      final result = await runZfa(['bone']);
      expectUsageError(result, 'usage: zfa bone SUBCOMMAND');
    });

    test('`zfa bone <unknown>` exits 2', () async {
      final result = await runZfa(['bone', 'not-a-subcommand']);
      expectUsageError(result, 'Unknown bone subcommand: not-a-subcommand');
    });

    test('bare `zfa config` exits 2', () async {
      final result = await runZfa(['config']);
      expectUsageError(result, 'zfa config - Manage ZFA configuration');
    });

    test('`zfa config <unknown>` exits 2 (usage class, not 1)', () async {
      final result = await runZfa(['config', 'not-a-subcommand']);
      expectUsageError(result, 'Unknown config command');
    });

    test('`zfa config set` with no key/value exits 2', () async {
      final result = await runZfa(['config', 'set']);
      expectUsageError(result, 'Usage: zfa config set');
    });

    test('bare `zfa migrate` exits 2', () async {
      final result = await runZfa(['migrate']);
      expectUsageError(result, 'USAGE: zfa migrate <target>');
    });

    test('`zfa migrate <unknown>` exits 2 (was 0)', () async {
      final result = await runZfa(['migrate', 'not-a-target']);
      expectUsageError(result, 'Unknown migration target: not-a-target');
    });

    test('bare `zfa plugin` exits 2', () async {
      final result = await runZfa(['plugin']);
      expectUsageError(result, 'zfa plugin - Manage ZFA plugins');
    });

    test('`zfa plugin <unknown>` exits 2 (usage class, not 1)', () async {
      final result = await runZfa(['plugin', 'not-an-action']);
      expectUsageError(result, 'Unknown plugin command: not-an-action');
    });

    test('`zfa plugin enable` with no id exits 2', () async {
      final result = await runZfa(['plugin', 'enable']);
      expectUsageError(result, 'Missing plugin id');
    });

    test('explicit --help keeps exiting 0 (help is success)', () async {
      for (final cmd in ['benchmark', 'bone', 'migrate', 'plugin']) {
        final result = await runZfa([cmd, '--help']);
        expect(
          result.exitCode,
          equals(0),
          reason:
              '`zfa $cmd --help` is a successful outcome (exit 0), not a '
              'usage error.\n${combinedOutput(result)}',
        );
      }
    });
  });
}
