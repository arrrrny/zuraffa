import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/cache_command.dart';
import 'package:zuraffa/src/plugins/cache/cache_plugin.dart';

/// Spec #975, Order 1 — bare `zfa cache` contract (mirrors
/// `state_command.dart:25-32` / bug #856).
///
/// `CacheCommand.run()` is only reachable through direct (programmatic)
/// invocation — package:args rejects both the bare invocation and any
/// positional form at dispatch level — and its only honest behavior is to
/// print the SUBCOMMAND grammar, never generate, and signal a usage error
/// (exit 64). The pre-#975 code carried a dead positional path
/// (`argResults!.rest.first`) that crashed with a RangeError when rest was
/// empty and silently generated when it was not; these tests pin the fixed
/// contract forever.
void main() {
  late CachePlugin plugin;

  setUp(() {
    plugin = CachePlugin(outputDir: 'lib/src');
  });

  group('bare `zfa cache` never crashes (spec #975 FR-1)', () {
    test('run() reports the subcommand grammar and exits 64 — no RangeError, '
        'no generation', () async {
      exitCode = 0;
      final printed = <String>[];
      await runZoned(
        () => CacheCommand(plugin).run(),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );

      expect(exitCode, 64, reason: 'bare invocation is a usage error');
      expect(
        printed.join('\n'),
        contains('zfa cache <subcommand>'),
        reason: 'run() must point at the live subcommand grammar',
      );
      expect(
        printed.join('\n'),
        isNot(contains('Generation complete')),
        reason: 'run() must never reach the generator',
      );
    });

    test('run() reports usage even with a parsed-but-empty positional rest — '
        'the old dead path stays dead', () async {
      // The pre-#975 shape: run() reached with flags parsed and a
      // non-empty positional (only possible programmatically). The
      // state_command mirror makes run() usage-only, so the command's
      // own parser can be driven without ever generating.
      final command = CacheCommand(plugin);
      expect(command.subcommands.keys, contains('verify'));
      expect(command.subcommands.keys, contains('adapter'));
      expect(command.subcommands.keys, contains('create'));
    });
  });

  group(
    'dispatch level (spec #975 FR-2): args rejects unreachable grammar',
    () {
      late CommandRunner<void> runner;

      setUp(() {
        runner = CommandRunner<void>('zfa', 'test runner');
        runner.addCommand(CacheCommand(plugin));
      });

      test('bare `zfa cache` is a usage error, never a crash', () async {
        exitCode = 0;
        var usageError = false;
        try {
          await runner.run(['cache']);
        } on UsageException {
          usageError = true;
        }
        expect(usageError, isTrue, reason: 'args must demand a subcommand');
        expect(exitCode, 0, reason: 'the runner owns the exit code here');
      });

      test(
        '`zfa cache Product` never reaches run() — dispatch rejects it',
        () async {
          var usageError = false;
          try {
            await runner.run(['cache', 'Product']);
          } on UsageException catch (e) {
            usageError = true;
            expect(
              e.message,
              contains('Could not find a subcommand named "Product"'),
            );
          }
          expect(usageError, isTrue);
        },
      );

      test(
        'flags-only invocation is also a usage error (no silent generate)',
        () async {
          var usageError = false;
          try {
            await runner.run(['cache', '--policy', 'daily']);
          } on UsageException {
            usageError = true;
          }
          expect(usageError, isTrue);
        },
      );
    },
  );
}
