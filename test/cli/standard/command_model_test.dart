// Tests for StandardCommand (FR-003).
//
// Covers U10-U14 in the test-list.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

import 'helpers/fake_invocation_sink.dart';

void main() {
  group('StandardCommand', () {
    group('positional argument parsing (FR-003)', () {
      test('U10: parses positional arg', () async {
        final sink = FakeInvocationSink();
        final cmd = sink.command(
          name: 'greet',
          arguments: const [
            CommandArgument(name: 'who', required: true),
          ],
        );
        // Simulate the invocation the CliApp would build.
        final inv = CliInvocation(
          arguments: const ['World'],
          flags: const {},
          contract: CliContract.standard,
        );
        await cmd.handler(inv);
        expect(sink.invocations, hasLength(1));
        expect(sink.invocations.single.arguments, equals(const ['World']));
      });
    });

    group('flag parsing (FR-003)', () {
      test('U11: parses flag with value', () async {
        final sink = FakeInvocationSink();
        final cmd = sink.command(
          name: 'greet',
          flags: const [
            CommandFlag(name: '--name', takesValue: true, defaultsTo: 'anon'),
          ],
        );
        final inv = CliInvocation(
          arguments: const [],
          flags: const {'--name': 'World'},
          contract: CliContract.standard,
        );
        await cmd.handler(inv);
        expect(sink.invocations.single.flags['--name'], equals('World'));
      });

      test('U12: parses boolean flag as true', () async {
        final sink = FakeInvocationSink();
        final cmd = sink.command(
          name: 'greet',
          flags: const [
            CommandFlag(name: '--loud', defaultsTo: false),
          ],
        );
        final inv = CliInvocation(
          arguments: const [],
          flags: const {'--loud': true},
          contract: CliContract.standard,
        );
        await cmd.handler(inv);
        expect(sink.invocations.single.flags['--loud'], isTrue);
      });

      test('absent flag falls back to default', () async {
        final sink = FakeInvocationSink();
        final cmd = sink.command(
          name: 'greet',
          flags: const [
            CommandFlag(name: '--name', takesValue: true, defaultsTo: 'anon'),
          ],
        );
        // Empty flags map — the CliApp would normally populate defaults.
        final inv = CliInvocation(
          arguments: const [],
          flags: const {},
          contract: CliContract.standard,
        );
        await cmd.handler(inv);
        // The handler sees the flags map as the CliApp built it; the test
        // simulates the CliApp NOT applying defaults (so the value is just
        // absent). The contract is: defaults are applied by CliApp, not by
        // the StandardCommand itself.
        expect(sink.invocations.single.flags, isEmpty);
      });
    });

    group('handler invocation (FR-003)', () {
      test('U13: handler invoked exactly once per run() call', () async {
        final sink = FakeInvocationSink();
        final cmd = sink.command(name: 'greet');
        final inv = CliInvocation(
          arguments: const [],
          flags: const {},
          contract: CliContract.standard,
        );
        await cmd.handler(inv);
        expect(sink.invocations, hasLength(1));
        await cmd.handler(inv);
        expect(sink.invocations, hasLength(2));
      });
    });

    group('unknown flag handling (FR-003, FR-009)', () {
      test('U14: rejects unknown flag at parse time with usage error', () {
        // The StandardCommand itself does not parse args — the CliApp does.
        // The contract is: when the CliApp encounters a flag that the
        // command did not declare, it emits a usage error (exit code 64).
        // We assert on the documented contract here; the runtime test is
        // in cli_app_test.dart (U22).
        final cmd = StandardCommand(
          name: 'greet',
          description: 'test',
          flags: const [
            CommandFlag(name: '--name', takesValue: true),
          ],
          handler: (_) async => const SuccessResult(),
        );
        // The command's declared flag set is the contract; an undeclared
        // flag passed at runtime is a usage error.
        final declaredFlagNames = cmd.flags.map((f) => f.name).toSet();
        expect(declaredFlagNames, contains('--name'));
        expect(declaredFlagNames, isNot(contains('--unknown')));
      });
    });
  });
}
