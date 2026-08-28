// Tests for SharedCommand (FR-006, FR-009).
//
// Covers U32-U35 in the test-list.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  late CommandRegistry registry;

  setUp(() {
    registry = CommandRegistry();
  });

  StandardCommand makeGreetCommand() {
    return StandardCommand(
      name: 'greet',
      description: 'test greet',
      flags: const [CommandFlag(name: '--name', takesValue: true)],
      handler: (inv) async => SuccessResult(
        data: {'msg': 'hi ${inv.flags['--name'] ?? 'world'}'},
      ),
    );
  }

  group('SharedCommand', () {
    group('share + retrieve (FR-006)', () {
      test('U32: share publishes to registry', () {
        final shared = SharedCommand.of(
          makeGreetCommand(),
          version: '1.0.0',
        );
        shared.share(registry, ownerApp: 'A');
        expect(registry.contains('A', 'greet'), isTrue);
        final entry = registry.lookup('A', 'greet')!;
        expect(entry.version, equals('1.0.0'));
      });

      test('U33: retrieve satisfies version when published >= min', () {
        final shared = SharedCommand.of(
          makeGreetCommand(),
          version: '1.0.0',
        );
        shared.share(registry, ownerApp: 'A');
        final retrieved = SharedCommand.retrieve(
          registry,
          ownerApp: 'A',
          commandName: 'greet',
          minVersion: '1.0.0',
        );
        expect(retrieved.version, equals('1.0.0'));
        expect(retrieved.command.name, equals('greet'));
      });

      test('retrieve without minVersion always succeeds', () {
        final shared = SharedCommand.of(
          makeGreetCommand(),
          version: '1.0.0',
        );
        shared.share(registry, ownerApp: 'A');
        final retrieved = SharedCommand.retrieve(
          registry,
          ownerApp: 'A',
          commandName: 'greet',
        );
        expect(retrieved.command.name, equals('greet'));
      });

      test('retrieve higher published version satisfies lower min', () {
        final shared = SharedCommand.of(
          makeGreetCommand(),
          version: '2.0.0',
        );
        shared.share(registry, ownerApp: 'A');
        final retrieved = SharedCommand.retrieve(
          registry,
          ownerApp: 'A',
          commandName: 'greet',
          minVersion: '1.5.0',
        );
        expect(retrieved.version, equals('2.0.0'));
      });

      test('U34: retrieve rejects lower version with VersionMismatchException',
          () {
        final shared = SharedCommand.of(
          makeGreetCommand(),
          version: '1.0.0',
        );
        shared.share(registry, ownerApp: 'A');
        late VersionMismatchException err;
        try {
          SharedCommand.retrieve(
            registry,
            ownerApp: 'A',
            commandName: 'greet',
            minVersion: '2.0.0',
          );
          fail('expected VersionMismatchException');
        } on VersionMismatchException catch (e) {
          err = e;
        }
        expect(err.commandName, equals('greet'));
        expect(err.ownerApp, equals('A'));
        expect(err.requestedMinVersion, equals('2.0.0'));
        expect(err.publishedVersion, equals('1.0.0'));
      });
    });

    group('retrieved command runs identically (FR-006)', () {
      test('U35: retrieved runs identically', () async {
        final shared = SharedCommand.of(
          makeGreetCommand(),
          version: '1.0.0',
        );
        shared.share(registry, ownerApp: 'A');
        final retrieved = SharedCommand.retrieve(
          registry,
          ownerApp: 'A',
          commandName: 'greet',
          minVersion: '1.0.0',
        );
        final inv1 = CliInvocation(
          arguments: const [],
          flags: const {'--name': 'World'},
          contract: CliContract.standard,
        );
        final inv2 = CliInvocation(
          arguments: const [],
          flags: const {'--name': 'World'},
          contract: CliContract.standard,
        );
        final r1 = await shared.command.handler(inv1);
        final r2 = await retrieved.command.handler(inv2);
        expect(r1.outcome, equals(r2.outcome));
        expect(
          (r1 as SuccessResult).data['msg'],
          equals((r2 as SuccessResult).data['msg']),
        );
      });
    });

    group('version comparison (FR-009 edge case 5)', () {
      test('1.0.0 satisfies 1.0.0', () {
        expect(
          SharedCommand.versionSatisfies('1.0.0', '1.0.0'),
          isTrue,
        );
      });

      test('2.0.0 satisfies 1.0.0', () {
        expect(
          SharedCommand.versionSatisfies('2.0.0', '1.0.0'),
          isTrue,
        );
      });

      test('1.0.0 does not satisfy 2.0.0', () {
        expect(
          SharedCommand.versionSatisfies('1.0.0', '2.0.0'),
          isFalse,
        );
      });

      test('1.2.0 satisfies 1.0.0', () {
        expect(
          SharedCommand.versionSatisfies('1.2.0', '1.0.0'),
          isTrue,
        );
      });

      test('1.0.3 satisfies 1.0.0', () {
        expect(
          SharedCommand.versionSatisfies('1.0.3', '1.0.0'),
          isTrue,
        );
      });

      test('1.0.0 does not satisfy 1.0.1', () {
        expect(
          SharedCommand.versionSatisfies('1.0.0', '1.0.1'),
          isFalse,
        );
      });
    });
  });
}
