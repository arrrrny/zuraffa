// Pins the wrapped `zfa tdd` usage contract (issue #1452).
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

  test('usageException wraps message and usage at the runner width', () {
    final runner = CommandRunner<void>(
      'zfa',
      'Zuraffa Code Generator',
      usageLineLength: 80,
    )..addCommand(TddCommand(TddPlugin()));
    final tdd = runner.commands['tdd']!;

    try {
      tdd.usageException('a ' * 100);
      fail('expected UsageException');
    } on UsageException catch (e) {
      expect(
        e.message.split('\n'),
        everyElement(hasLength(lessThanOrEqualTo(80))),
      );
      expect(e.usage, contains('Available subcommands:'));
    }
  });

  test('usage follows the runner width, not the constant', () {
    final runner = CommandRunner<void>(
      'zfa',
      'Zuraffa Code Generator',
      usageLineLength: 80,
    )..addCommand(TddCommand(TddPlugin()));

    final lines = runner.commands['tdd']!.usage.split('\n');

    expect(lines, everyElement(hasLength(lessThanOrEqualTo(80))));
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

  test(
    'zfa tdd usage layout: blank lines between entries, aligned continuations',
    () {
      final runner = CommandRunner<void>(
        'zfa',
        'Zuraffa Code Generator',
        usageLineLength: 120,
      )..addCommand(TddCommand(TddPlugin()));
      final tdd = runner.commands['tdd']!;

      final lines = tdd.usage.split('\n');
      final entryRe = RegExp(r'^  (\S+) +');
      final runIndex = lines.indexWhere((line) => line.startsWith('Run '));
      expect(runIndex, greaterThan(0));

      // The subcommand section sits between its header and the footer line.
      final section = lines.sublist(
        lines.indexOf('Available subcommands:') + 1,
        runIndex,
      );

      // Split into entry blocks separated by blank lines: each block is one
      // subcommand entry plus its wrapped continuation lines.
      final blocks = <List<String>>[];
      var current = <String>[];
      for (final line in section) {
        if (line.isEmpty) {
          if (current.isNotEmpty) {
            blocks.add(current);
            current = <String>[];
          }
        } else {
          current.add(line);
        }
      }
      if (current.isNotEmpty) blocks.add(current);

      // Every visible subcommand renders as exactly one block.
      final expected = tdd.subcommands.entries
          .where(
            (entry) =>
                !entry.value.hidden && !entry.value.aliases.contains(entry.key),
          )
          .map((entry) => entry.key)
          .toSet();
      expect(blocks.length, expected.length);

      final summaryColumns = <int>{};
      for (final block in blocks) {
        final match = entryRe.firstMatch(block.first);
        expect(
          match,
          isNotNull,
          reason: 'block must start with a subcommand entry',
        );
        final name = match!.group(1)!;
        expect(
          expected.contains(name),
          isTrue,
          reason: 'entry "$name" must be a tdd subcommand',
        );
        final summaryColumn = match.end;
        summaryColumns.add(summaryColumn);

        // Continuation lines align under the summary column.
        for (final line in block.skip(1)) {
          expect(
            line.indexOf(line.trim()),
            summaryColumn,
            reason:
                'continuation must align under the summary column of "$name"',
          );
        }
      }
      expect(
        summaryColumns.length,
        1,
        reason: 'all entries share one summary column',
      );
    },
  );
}
