// Tests for edge-case exceptions (FR-009).
//
// Covers U41-U45 in the test-list.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('Edge cases (FR-009)', () {
    group('UnknownCommandException', () {
      test('U41: carries command name and hint with available commands', () {
        final e = UnknownCommandException(
          commandName: 'grete',
          availableCommands: const ['A/greet', 'A/list'],
        );
        expect(e.code, equals('notFound'));
        expect(e.commandName, equals('grete'));
        expect(e.availableCommands, equals(['A/greet', 'A/list']));
        expect(e.message, contains('grete'));
        expect(e.message, contains('A/greet'));
        expect(e.details['commandName'], equals('grete'));
        expect(e.details['availableCommands'], equals(['A/greet', 'A/list']));
      });

      test('message includes owner app when provided', () {
        final e = UnknownCommandException(
          commandName: 'missing',
          ownerApp: 'A',
          availableCommands: const [],
        );
        expect(e.message, contains('in app "A"'));
      });
    });

    group('AmbiguousCommandException', () {
      test('U42: carries ambiguous name and matching pairs', () {
        final e = AmbiguousCommandException(
          commandName: 'greet',
          matches: const ['A/greet', 'B/greet'],
        );
        expect(e.code, equals('conflict'));
        expect(e.commandName, equals('greet'));
        expect(e.matches.toSet(), equals({'A/greet', 'B/greet'}));
        expect(e.details['matches'], equals(['A/greet', 'B/greet']));
        expect(e.message, contains('multiple apps'));
        expect(e.message, contains('disambiguate'));
      });
    });

    group('ReferencedAppMissingException', () {
      test('carries owner app and registered apps', () {
        final e = ReferencedAppMissingException(
          ownerApp: 'B',
          registeredApps: const ['A', 'C'],
        );
        expect(e.code, equals('notFound'));
        expect(e.ownerApp, equals('B'));
        expect(e.registeredApps.toSet(), equals({'A', 'C'}));
        expect(e.message, contains('App "B"'));
        expect(e.message, contains('not registered'));
      });
    });

    group('CircularReferenceException', () {
      test('U43: carries the chain that formed the cycle', () {
        final e = CircularReferenceException(
          chain: const ['A/greet', 'B/greet', 'A/greet'],
        );
        expect(e.code, equals('circularRef'));
        expect(e.chain, equals(['A/greet', 'B/greet', 'A/greet']));
        expect(e.details['chain'], equals(['A/greet', 'B/greet', 'A/greet']));
        expect(e.message, contains('A/greet -> B/greet -> A/greet'));
      });
    });

    group('VersionMismatchException', () {
      test('U44: carries requested min and published version', () {
        final e = VersionMismatchException(
          commandName: 'greet',
          ownerApp: 'A',
          requestedMinVersion: '2.0.0',
          publishedVersion: '1.0.0',
        );
        expect(e.code, equals('versionMismatch'));
        expect(e.commandName, equals('greet'));
        expect(e.ownerApp, equals('A'));
        expect(e.requestedMinVersion, equals('2.0.0'));
        expect(e.publishedVersion, equals('1.0.0'));
        expect(e.details['requestedMinVersion'], equals('2.0.0'));
        expect(e.details['publishedVersion'], equals('1.0.0'));
        expect(e.message, contains('A/greet'));
        expect(e.message, contains('1.0.0'));
        expect(e.message, contains('2.0.0'));
      });
    });

    group('NonInteractiveContextException', () {
      test('U45: raised when command requires interaction but stdout is piped',
          () {
        final e = NonInteractiveContextException(
          commandName: 'prompt',
          reason: 'stdout is piped',
        );
        expect(e.code, equals('usage'));
        expect(e.commandName, equals('prompt'));
        expect(e.reason, equals('stdout is piped'));
        expect(e.details['commandName'], equals('prompt'));
        expect(e.details['reason'], equals('stdout is piped'));
        expect(e.message, contains('interactive terminal'));
      });
    });

    group('CommandAlreadyRegistered', () {
      test('is a conflict-code edge case at registration time', () {
        final e = CommandAlreadyRegistered(
          const RegistryKey('A', 'greet'),
          existingVersion: '1.0.0',
        );
        expect(e.code, equals('conflict'));
        expect(e.key.toString(), equals('A/greet'));
        expect(e.existingVersion, equals('1.0.0'));
        expect(e.message, contains('A/greet'));
        expect(e.message, contains('1.0.0'));
      });
    });

    group('BindingException', () {
      test('is a runtime-code edge case for DI binding failures', () {
        final e = BindingException(
          commandName: 'list-users',
          dependencyName: 'UserRepository',
          reason: 'not registered in host DI',
        );
        expect(e.code, equals('runtime'));
        expect(e.commandName, equals('list-users'));
        expect(e.dependencyName, equals('UserRepository'));
        expect(e.details['commandName'], equals('list-users'));
        expect(e.details['dependencyName'], equals('UserRepository'));
      });
    });
  });
}
