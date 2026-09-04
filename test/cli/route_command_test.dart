// U4: `zfa route verify` is reachable as a subcommand with
// `--json` / `--plain` / `--strict` / `--out` flags.

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/route_command.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

void main() {
  group('RouteCommand', () {
    late CommandRunner<void> runner;

    setUp(() {
      runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(RouteCommand(RoutePlugin(outputDir: 'lib/src')));
    });

    test('U4.1: registers a `verify` subcommand', () {
      final names = runner.commands['route']!.subcommands.keys.toList();
      expect(names, contains('verify'));
    });

    test('U4.2: `route verify` accepts --json, --plain, --strict, --out', () {
      final route = runner.commands['route']!;
      final verify = route.subcommands['verify']!;
      final opts = verify.argParser.options.keys.toList();
      expect(opts, contains('json'));
      expect(opts, contains('plain'));
      expect(opts, contains('strict'));
      expect(opts, contains('out'));
    });

    test('U4.3: `route --help` advertises verify among the subcommands', () {
      final help = runner.commands['route']!.usage;
      expect(help, contains('verify'));
    });
  });
}
