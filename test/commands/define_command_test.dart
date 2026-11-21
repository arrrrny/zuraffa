import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// Issue #2114 — the `define` grammar.
///
/// `zfa define --help` exited 2 with `Could not find a command named
/// "define"`: the top-level registry exposed `usecase create`,
/// `service create` and `provider create` but no `define` verb, so the
/// domain/application types could not be defined through the grammar the
/// generation contract advertises.
///
/// The fix mounts the EXISTING create commands under a `define` group —
/// `zfa define usecase <Name>` ≡ `zfa usecase create <Name>`, and the same
/// for `service` and `provider`. Fresh command instances are mounted (never
/// the instances the plugin commands own): package:args binds a subcommand
/// to ONE parent, and a second registration of the same object leaves it
/// unparented, which is the `--help` crash of issue #761.
void main() {
  group('zfa define (issue #2114)', () {
    test('`define --help` prints the group and exits 0', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['define', '--help']);

      expect(out, isNot(contains('Could not find a command named')));
      expect(out, isNot(contains('Null check operator')));
      expect(
        out,
        contains('usecase'),
        reason: 'the define group must advertise its usecase subcommand',
      );
      expect(out, contains('service'));
      expect(out, contains('provider'));
      expect(CliRunner.lastDispatchedExitCode, 0);
    });

    test('`define` with no subcommand is a usage error', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['define']);

      expect(out, contains('--> fix:'));
      expect(CliRunner.lastDispatchedExitCode, 2);
    });

    test('`define usecase --help` prints the create grammar', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['define', 'usecase', '--help']);

      expect(out, isNot(contains('Null check operator')));
      expect(out, contains('--params'));
      expect(out, contains('--returns'));
    });

    test('`define service --help` prints the create grammar', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['define', 'service', '--help']);

      expect(out, isNot(contains('Null check operator')));
      expect(out, contains('--params'));
      expect(out, contains('--returns'));
      expect(out, contains('--type'));
    });

    test('`define provider --help` prints the create grammar', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['define', 'provider', '--help']);

      expect(out, isNot(contains('Null check operator')));
      expect(out, contains('--params'));
      expect(out, contains('--returns'));
    });

    test('`define usecase` with no name echoes the define grammar', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['define', 'usecase']);

      expect(out, contains('Usage: zfa define usecase <EntityName> [options]'));
      expect(out, isNot(contains('Usage: zfa usecase create')));
    });

    test('`define service` with no name echoes the define grammar', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['define', 'service']);

      expect(out, contains('zfa define service <ServiceName>'));
      expect(out, isNot(contains('zfa service create')));
    });
  });
}
