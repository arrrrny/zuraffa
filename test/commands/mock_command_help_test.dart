import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/commands/mock_command.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

/// Regression tests for issue #761: `zfa mock json --help` crashed with
/// "Null check operator used on a null value" instead of printing usage.
///
/// Root cause: `PluginCommand`'s constructor auto-registers every capability
/// as a `CapabilityCommand` (so `json` is already on MockCommand's argParser
/// via `JsonMockCapability.name == 'json'`). `MockCommand` then re-registers
/// the richer `JsonMockCommand` under the same name; in package:args,
/// `addSubcommand` sets the map entry before `argParser.addCommand` (which
/// throws on the duplicate) and only sets `command._parent` last — so
/// `_parent` stayed null and the thrown `ArgumentError` was silently
/// swallowed by `MockCommand`'s `catch (_) {}`. A subcommand with a null
/// parent resolves `runner` to null, and `Command.invocation` crashes on
/// `runner!.executableName` when `--help` prints usage.
void main() {
  group('mock json --help (issue #761)', () {
    test('prints usage instead of crashing on a null runner', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['mock', 'json', '--help']);

      expect(out, isNot(contains('Null check operator')));
      expect(out, isNot(contains('❌ Error:')));
      expect(out, contains('json'));
    });

    test('the registered JsonMockCommand is fully parented', () {
      final plugin = MockPlugin(outputDir: 'lib/src');
      final command = plugin.createCommand();

      expect(command, isA<MockCommand>());

      // Attach to a real runner so the whole parent→runner chain resolves.
      final commandRunner = CommandRunner<void>('zfa', 'test')
        ..addCommand(command as Command<void>);

      final json = commandRunner.commands['mock']!.subcommands['json'];
      expect(json, isA<JsonMockCommand>());

      // The exact broken state behind the crash: a null parent makes the
      // args package resolve `runner` to null, so `invocation` (used to
      // render help) throws "Null check operator used on a null value".
      expect(json!.parent, isA<Command<void>>());
      expect(json.runner, same(commandRunner));
    });

    test('sibling subcommands still print help (regression guard)', () async {
      final runner = CliRunner(exitOnCompletion: false);

      final data = await runner.runCapturing(['mock', 'data', '--help']);
      expect(data, isNot(contains('Null check operator')));
      expect(data, contains('data'));

      final mock = await runner.runCapturing(['mock', '--help']);
      expect(mock, isNot(contains('Null check operator')));
      expect(mock, contains('create'));
    });
  });
}
