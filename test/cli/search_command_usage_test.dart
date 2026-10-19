import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';
import 'package:zuraffa/src/commands/search_command.dart';

Future<String> captureOutput(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

void main() {
  test('SearchCommand is registrable under a CommandRunner', () {
    final runner = CommandRunner<void>('zfa', 'Zuraffa Code Generator')
      ..addCommand(SearchCommand());
    expect(runner.commands, contains('search'));
    expect(runner.commands['search'], isA<SearchCommand>());
  });

  test('zfa search prints usage and exits with ExitProtocol.usage', () async {
    final runner = CommandRunner<void>('zfa', 'Zuraffa Code Generator')
      ..addCommand(SearchCommand());

    final output = await captureOutput(() => runner.run(['search']));

    expect(output, contains('Usage: zfa search'));
    expect(output, contains('No subcommands are registered yet'));
    expect(exitCode, ExitProtocol.usage);
  });
}
