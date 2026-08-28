// Tests for CommandRegistry (FR-004, FR-009).
//
// Covers U23-U27 in the test-list.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  late CommandRegistry registry;

  setUp(() {
    registry = CommandRegistry();
  });

  StandardCommand makeCommand(String name, {String description = ''}) {
    return StandardCommand(
      name: name,
      description: description,
      handler: (_) async => const SuccessResult(),
    );
  }

  group('CommandRegistry', () {
    group('register + lookup (FR-004)', () {
      test('U23: register then lookup', () {
        registry.register(makeCommand('greet'), ownerApp: 'A');
        final entry = registry.lookup('A', 'greet');
        expect(entry, isNotNull);
        expect(entry!.command.name, equals('greet'));
        expect(entry.ownerApp, equals('A'));
      });

      test('lookup returns null for missing key', () {
        expect(registry.lookup('A', 'missing'), isNull);
      });

      test('contains returns false for unregistered key', () {
        expect(registry.contains('A', 'greet'), isFalse);
      });

      test('require throws UnknownCommandException for missing key', () {
        expect(
          () => registry.require('A', 'missing'),
          throwsA(isA<UnknownCommandException>()),
        );
      });
    });

    group('duplicate registration (FR-004, FR-009)', () {
      test('U24: duplicate registration throws', () {
        registry.register(makeCommand('greet'), ownerApp: 'A');
        expect(
          () => registry.register(makeCommand('greet'), ownerApp: 'A'),
          throwsA(isA<CommandAlreadyRegistered>()),
        );
      });

      test('re-registration error carries the existing version', () {
        registry.register(
          makeCommand('greet'),
          ownerApp: 'A',
          version: '1.2.3',
        );
        late CommandAlreadyRegistered err;
        try {
          registry.register(makeCommand('greet'), ownerApp: 'A');
          fail('expected CommandAlreadyRegistered');
        } on CommandAlreadyRegistered catch (e) {
          err = e;
        }
        expect(err.existingVersion, equals('1.2.3'));
      });
    });

    group('enumerate (FR-004)', () {
      test('U25: enumerate returns all', () {
        registry.register(makeCommand('greet'), ownerApp: 'A');
        registry.register(makeCommand('list'), ownerApp: 'B');
        final all = registry.enumerate();
        expect(all, hasLength(2));
        expect(all.map((c) => c.key.toString()).toSet(),
            equals({'A/greet', 'B/list'}));
      });

      test('U26: enumerateFor scopes by owner', () {
        registry.register(makeCommand('greet'), ownerApp: 'A');
        registry.register(makeCommand('list'), ownerApp: 'A');
        registry.register(makeCommand('foo'), ownerApp: 'B');
        expect(registry.enumerateFor('A'), hasLength(2));
        expect(registry.enumerateFor('B'), hasLength(1));
        expect(registry.enumerateFor('C'), isEmpty);
      });

      test('enumerate returns empty for empty registry', () {
        expect(registry.enumerate(), isEmpty);
      });
    });

    group('namespacing rule (FR-004, FR-009)', () {
      test('U27: same name different owner coexists', () {
        // Two apps registering a command named 'greet' must coexist — the
        // namespacing rule is `(ownerApp, name)`, not `name` alone.
        registry.register(makeCommand('greet'), ownerApp: 'A');
        registry.register(makeCommand('greet'), ownerApp: 'B');
        expect(registry.length, equals(2));
        expect(registry.contains('A', 'greet'), isTrue);
        expect(registry.contains('B', 'greet'), isTrue);
      });

      test('enumerateByName returns both owners', () {
        registry.register(makeCommand('greet'), ownerApp: 'A');
        registry.register(makeCommand('greet'), ownerApp: 'B');
        final matches = registry.enumerateByName('greet');
        expect(matches, hasLength(2));
        expect(matches.map((m) => m.ownerApp).toSet(), equals({'A', 'B'}));
      });

      test('enumerateByName returns empty for missing name', () {
        expect(registry.enumerateByName('missing'), isEmpty);
      });
    });

    test('clear removes all registrations', () {
      registry.register(makeCommand('greet'), ownerApp: 'A');
      registry.register(makeCommand('list'), ownerApp: 'B');
      registry.clear();
      expect(registry.length, isZero);
      expect(registry.enumerate(), isEmpty);
    });
  });
}
