// Tests for CrossAppInvoker (FR-005, FR-009).
//
// Covers U28-U31 in the test-list.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  late CommandRegistry registry;
  late CrossAppInvoker invoker;

  setUp(() {
    registry = CommandRegistry();
    invoker = CrossAppInvoker(registry);
    CrossAppInvoker.resetForTest();
  });

  tearDown(() {
    CrossAppInvoker.resetForTest();
  });

  StandardCommand makeCommand(
    String name, {
    Future<CommandResult> Function(CliInvocation)? handler,
  }) {
    return StandardCommand(
      name: name,
      description: '',
      handler: handler ?? (_) async => const SuccessResult(data: {'ok': true}),
    );
  }

  group('CrossAppInvoker', () {
    group('invoke by owner and name (FR-005)', () {
      test('U28: invoke runs the command and returns its result', () async {
        registry.register(
          makeCommand(
            'greet',
            handler: (inv) async => SuccessResult(
              data: {'echo': inv.arguments.isEmpty ? '' : inv.arguments.first},
            ),
          ),
          ownerApp: 'A',
        );
        final inv = CliInvocation(
          arguments: const ['World'],
          flags: const {},
          contract: CliContract.standard,
        );
        final result = await invoker.invoke('A', 'greet', inv);
        expect(result, isA<SuccessResult>());
        expect((result as SuccessResult).data['echo'], equals('World'));
      });

      test('invoke by name with no args returns success', () async {
        registry.register(makeCommand('ping'), ownerApp: 'A');
        final inv = CliInvocation(
          arguments: const [],
          flags: const {},
          contract: CliContract.standard,
        );
        final result = await invoker.invoke('A', 'ping', inv);
        expect(result.outcome, equals('success'));
      });
    });

    group('unknown command (FR-005, FR-009)', () {
      test('U29: unknown command throws UnknownCommandException', () async {
        registry.register(makeCommand('greet'), ownerApp: 'A');
        final inv = CliInvocation(
          arguments: const [],
          flags: const {},
          contract: CliContract.standard,
        );
        expect(
          () => invoker.invoke('A', 'missing', inv),
          throwsA(isA<UnknownCommandException>()),
        );
      });

      test(
        'invokeByName throws UnknownCommandException when no match',
        () async {
          final inv = CliInvocation(
            arguments: const [],
            flags: const {},
            contract: CliContract.standard,
          );
          expect(
            () => invoker.invokeByName('missing', inv),
            throwsA(isA<UnknownCommandException>()),
          );
        },
      );
    });

    group('missing owner app (FR-005, FR-009)', () {
      test(
        'U30: missing owner app throws ReferencedAppMissingException',
        () async {
          registry.register(makeCommand('greet'), ownerApp: 'A');
          final inv = CliInvocation(
            arguments: const [],
            flags: const {},
            contract: CliContract.standard,
          );
          expect(
            () => invoker.invoke('B', 'greet', inv),
            throwsA(isA<ReferencedAppMissingException>()),
          );
        },
      );

      test('ReferencedAppMissingException lists registered apps', () async {
        registry.register(makeCommand('greet'), ownerApp: 'A');
        registry.register(makeCommand('list'), ownerApp: 'C');
        final inv = CliInvocation(
          arguments: const [],
          flags: const {},
          contract: CliContract.standard,
        );
        late ReferencedAppMissingException err;
        try {
          await invoker.invoke('B', 'greet', inv);
          fail('expected exception');
        } on ReferencedAppMissingException catch (e) {
          err = e;
        }
        expect(err.registeredApps.toSet(), containsAll(['A', 'C']));
        expect(err.registeredApps, isNot(contains('B')));
      });
    });

    group('ambiguous name (FR-009 edge case 2)', () {
      test(
        'invokeByName throws AmbiguousCommandException on multiple owners',
        () async {
          registry.register(makeCommand('greet'), ownerApp: 'A');
          registry.register(makeCommand('greet'), ownerApp: 'B');
          final inv = CliInvocation(
            arguments: const [],
            flags: const {},
            contract: CliContract.standard,
          );
          late AmbiguousCommandException err;
          try {
            await invoker.invokeByName('greet', inv);
            fail('expected exception');
          } on AmbiguousCommandException catch (e) {
            err = e;
          }
          expect(err.commandName, equals('greet'));
          expect(err.matches.toSet(), equals({'A/greet', 'B/greet'}));
        },
      );
    });

    group('circular reference detection (FR-009 edge case 4)', () {
      test('U31: A calls B calls A is detected and halted', () async {
        // Command 'A.greet' invokes 'B.greet', which invokes 'A.greet'
        // again — a direct cycle.
        final inv = CliInvocation(
          arguments: const [],
          flags: const {},
          contract: CliContract.standard,
        );

        registry.register(
          makeCommand(
            'greet',
            handler: (_) async => invoker.invoke('B', 'greet', inv),
          ),
          ownerApp: 'A',
        );
        registry.register(
          makeCommand(
            'greet',
            handler: (_) async => invoker.invoke('A', 'greet', inv),
          ),
          ownerApp: 'B',
        );

        late CircularReferenceException err;
        try {
          await invoker.invoke('A', 'greet', inv);
          fail('expected CircularReferenceException');
        } on CircularReferenceException catch (e) {
          err = e;
        }
        // The chain starts at A/greet and ends at A/greet (the one that
        // closed the cycle).
        expect(err.chain.first, equals('A/greet'));
        expect(err.chain.last, equals('A/greet'));
        expect(err.chain.length, greaterThan(1));
      });

      test('non-cyclic chain does not raise', () async {
        // A calls B; B returns without calling back. No cycle.
        registry.register(
          makeCommand(
            'greet',
            handler: (_) async => invoker.invoke(
              'B',
              'bye',
              CliInvocation(
                arguments: const [],
                flags: const {},
                contract: CliContract.standard,
              ),
            ),
          ),
          ownerApp: 'A',
        );
        registry.register(
          makeCommand('bye', handler: (_) async => const SuccessResult()),
          ownerApp: 'B',
        );
        final result = await invoker.invoke(
          'A',
          'greet',
          CliInvocation(
            arguments: const [],
            flags: const {},
            contract: CliContract.standard,
          ),
        );
        expect(result.outcome, equals('success'));
      });
    });

    test('currentChain is empty when no invocations in flight', () {
      expect(invoker.hasInFlightInvocations, isFalse);
      expect(invoker.currentChain, isEmpty);
    });
  });
}
