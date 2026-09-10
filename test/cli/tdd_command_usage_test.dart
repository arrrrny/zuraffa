// Pins the wrapped `zfa tdd` usage contract (review of #1460, issue #1452).
//
// Pure-Dart: no package:flutter import.

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/tdd_command.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';

void main() {
  test('zfa tdd usage wraps summaries at 120 columns', () {
    final runner = CommandRunner<void>(
      'zfa',
      'Zuraffa Code Generator',
      usageLineLength: 120,
    )..addCommand(TddCommand(TddPlugin()));
    final tdd = runner.commands['tdd']!;

    final usage = tdd.usage;

    expect(usage, contains('Available subcommands:'));
    expect(usage.split('\n'), everyElement(hasLength(lessThanOrEqualTo(120))));
    expect(usage, contains('Run "zfa help" to see global options.'));
  });

  test('zfa tdd usage keeps the command description', () {
    final runner = CommandRunner<void>(
      'zfa',
      'Zuraffa Code Generator',
      usageLineLength: 120,
    )..addCommand(TddCommand(TddPlugin()));

    final usage = runner.commands['tdd']!.usage;

    expect(usage, contains('Drive the full TDD red-green-refactor cycle'));
  });
}
