import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// CLI registration tests for the `sqlite` command (issue #464):
/// `zfa sqlite [adapter] <Entity>` must be dispatched by the runner.
void main() {
  group('SqliteCommand', () {
    test('is exposed as `sqlite` in the top-level help', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final help = await runner.runCapturing(['--help']);
      expect(help, contains(' sqlite '));
    });

    test('dispatches `zfa sqlite --help`', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final help = await runner.runCapturing(['sqlite', '--help']);
      expect(help, contains('sqlite'));
    });

    test('dispatches `zfa sqlite adapter --help` (issue spelling)', () async {
      // The issue asks for `zfa sqlite adapter <Entity>`; `adapter` is
      // tolerated as a leading positional, so help must still dispatch.
      final runner = CliRunner(exitOnCompletion: false);
      final help = await runner.runCapturing(['sqlite', 'adapter', '--help']);
      expect(help, contains('sqlite'));
    });

    test('exposes the --methods option', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final help = await runner.runCapturing(['sqlite', '--help']);
      expect(help, contains('--methods'));
    });
  });
}
