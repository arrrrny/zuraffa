import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

/// Epic #1011 — TRUTH-FLOOR: regression for issue #1059.
///
/// `zfa entity cli` (and the parent `zfa entity`) previously printed a
/// usage message and exited 0 on bare invocation — a lying-success the
/// #1039 sweep was merged to eliminate fleet-wide. The `entity` family
/// was missed because `EntityCommand` predates the `PluginCommand`
/// hierarchy and owns its own dispatcher. PR #1039's convention is:
/// usage errors print a short `❌` banner and set `exitCode = 64`
/// (distinct from 1 = runtime failure). This test pins the contract
/// so the next drift off it fails loudly.
///
/// Driven through a real subprocess ([runZfaSource]) because the
/// `entity` command calls `exit(N)` on its error paths — a subprocess
/// keeps the test harness alive and the process-global `Directory.current`
/// hermetic under parallel `dart test` (issue #506 pattern, see
/// `entity_receipt_test.dart`).
void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_entity_cli_exit_');
    // Bare `zfa entity` is reachable before the pubspec guard fires (the
    // help / usage-error paths short-circuit before `_checkDependencies`).
    // `zfa entity cli` (with no entity name) currently routes through the
    // `_handleCli` path that doesn't touch the pubspec guard either, but
    // set up a minimal pubspec anyway so the test mirrors a real project
    // and any future guard movement doesn't silently break the contract.
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_entity_cli_exit_test
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
''');
  });

  tearDown(() {
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  group('epic #1011 / issue #1059 — entity cli bare invocation', () {
    test('`zfa entity cli` with no entity name exits 64 (not 0)', () async {
      final result = await runZfaSource([
        'entity',
        'cli',
      ], workingDirectory: workspace.path);

      // Truth-floor contract: usage errors exit 64, not 0. A 0 here is
      // the lying-success the #1039 sweep was meant to eliminate; this
      // is the exact regression #1059 names ("the one command the #995
      // sweep missed").
      expect(
        result.exitCode,
        equals(64),
        reason:
            'zfa entity cli with no entity name must exit 64 (usage-error '
            'family), not 0. exit=0 certifies "nothing went wrong" when '
            'nothing happened — the exact lie the TRUTH-FLOOR epic '
            '(#1011) forbids.\n'
            'stdout=${result.stdout}\nstderr=${result.stderr}',
      );

      // The usage-error banner must announce itself as an error (the
      // `❌` prefix is the #1039 convention shared with every other
      // swept command — see `reportSubcommandUsage` in
      // `lib/src/commands/base_plugin_command.dart`).
      final combined = '${result.stdout}${result.stderr}';
      expect(
        combined,
        contains('❌'),
        reason:
            'usage-error banner must use the ❌ prefix (the #1039 '
            'fleet-wide convention).',
      );
      expect(
        combined,
        contains('zfa entity cli'),
        reason: 'usage-error banner must name the offending command.',
      );

      // The phantom symbol `XRayControlDeckRegistry` (the lie the
      // previous test certified as the correct output) must NOT appear
      // anywhere in the usage output. Defensive: the previous behavior
      // printed a misleading "Usage: zfa entity cli <EntityName>" with
      // no ❌ prefix and exit 0; the new behavior must be unambiguous.
      expect(
        combined.contains('✅'),
        isFalse,
        reason: 'usage-error path must never print a ✅ success banner.',
      );
    });
  });

  group('epic #1011 / issue #1059 — sweep: `zfa entity` bare', () {
    test('`zfa entity` with no subcommand exits 64 (not 0)', () async {
      final result = await runZfaSource([
        'entity',
      ], workingDirectory: workspace.path);

      // The parent `zfa entity` previously called `_printHelp()` and
      // `exit(0)` on bare invocation — also a lying-success. The sweep
      // instruction in #1059 explicitly names this case ("zfa entity
      // bare, any other entity subcommands that print usage then return
      // void — fix all occurrences in the same PR").
      expect(
        result.exitCode,
        equals(64),
        reason:
            'zfa entity with no subcommand must exit 64 (usage-error '
            'family). Help is intentional (`--help`/`-h`/`help`); bare '
            'invocation is not — printing the full help and exiting 0 '
            'certifies "nothing went wrong" when nothing happened.\n'
            'stdout=${result.stdout}\nstderr=${result.stderr}',
      );

      final combined = '${result.stdout}${result.stderr}';
      expect(
        combined,
        contains('❌'),
        reason: 'usage-error banner must use the ❌ prefix.',
      );
      expect(
        combined,
        contains('zfa entity'),
        reason: 'usage-error banner must name the offending command.',
      );
    });

    test(
      '`zfa entity --help` stays exit 0 (help is NOT a usage error)',
      () async {
        final result = await runZfaSource([
          'entity',
          '--help',
        ], workingDirectory: workspace.path);

        // Help requests are intentional, not errors — they MUST keep
        // exit 0. This is the contract that distinguishes "user asked for
        // help" from "user invoked the command wrong": the former is a
        // valid use of the CLI, the latter is a usage error. Pinning this
        // here prevents an over-eager future sweep from turning `--help`
        // into a failure path (regression guard for #764, the prior fix
        // that made `--help` reachable outside a project root).
        expect(
          result.exitCode,
          equals(0),
          reason:
              'explicit --help must exit 0 — help is not a usage error.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );

        final combined = '${result.stdout}${result.stderr}';
        expect(combined, contains('USAGE'));
        expect(combined, contains('create'));
        // Help text must NOT use the ❌ prefix (that's reserved for
        // usage errors).
        expect(
          combined.contains('❌'),
          isFalse,
          reason: 'help text must not use the ❌ prefix.',
        );
      },
    );
  });
}
