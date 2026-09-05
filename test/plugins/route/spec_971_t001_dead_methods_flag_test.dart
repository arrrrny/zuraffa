// Spec 0971 / T001 — delete the dead `--methods` option from
// RouteCommand (route_command.dart).
//
// Bug #856 proved the parent `zfa route` grammar is unreachable through
// the CLI dispatch (package:args rejects a bare entity name as a
// subcommand attempt before run() ever executes), so the `--methods`
// option registered on RouteCommand is DEAD: no flag value parsed there
// can ever reach the generator. Meanwhile `zfa route --help` advertises
// it, misleading readers into `zfa route --methods get Product` — a
// command shape the dispatcher rejects. Order 1 of issue #971: delete
// the option; bare `zfa route` must keep exiting 64.
//
// Style: bug_912_route_dry_run_route_table_test.dart (failing-first,
// CLI surface pinned via runCapturing — see tdd_command_smoke_test).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  group('spec 0971 T001: dead --methods flag deleted from zfa route', () {
    test('zfa route --help no longer advertises --methods', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['route', '--help']);

      expect(
        out,
        isNot(contains('--methods')),
        reason:
            'issue #971 order 1: the dead --methods option (registered on '
            'the unreachable parent grammar, bug #856) must not appear in '
            '`zfa route --help` — it misleads readers into a dispatch shape '
            'package:args rejects',
      );
    });

    test('zfa route --help no longer advertises the -m abbreviation', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['route', '--help']);
      final optionsSection = out
          .split('\n')
          .where((line) => line.startsWith('  -'))
          .toList();

      expect(
        optionsSection,
        isNot(contains(contains('-m,'))),
        reason: 'the -m abbreviation of the dead option must be gone too',
      );
    });

    test('bare `zfa route` still reports the missing subcommand (exit 64 '
        'contract pinned by dead_positional_grammar_test FR-1/FR-3)', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['route']);

      expect(out, contains('Missing subcommand'));
      expect(
        out,
        contains('zfa route <subcommand>'),
        reason: 'bug #856 contract: bare zfa route must stay a usage error',
      );
    });

    test('zfa route --help still lists the live subcommands', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['route', '--help']);

      expect(out, contains('create'));
      expect(out, contains('verify'));
      expect(out, contains('custom'));
      expect(out, contains('deep-link'));
      expect(out, contains('shell'));
    });
  });
}
