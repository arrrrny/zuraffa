// Tests for DiBinding (FR-007, FR-009).
//
// Covers U36-U37 in the test-list.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

import 'helpers/fake_di_container.dart';

void main() {
  group('DiBinding', () {
    group('bind resolves from host DI (FR-007)', () {
      test('U36: bind resolves dependencies from host container', () async {
        final container = FakeDiContainer();
        container.register<UserRepository>(
          'UserRepository',
          UserRepositoryImpl(),
        );

        final shared = SharedCommand.of(
          StandardCommand(
            name: 'list-users',
            description: 'list users',
            handler: (_) async => const SuccessResult(),
          ),
          version: '1.0.0',
        );

        final binding = DiBinding.forHandler(
          dependencies: const [
            DependencyRequest(
              name: 'UserRepository',
              expectedType: UserRepository,
            ),
          ],
          boundHandler: (bound) async {
            final repo =
                bound.dependencies['UserRepository']! as UserRepository;
            final users = repo.all();
            return SuccessResult(data: {'users': users});
          },
        );

        final bound = binding.bind(shared, container: container);
        final result = await bound.handler(
          CliInvocation(
            arguments: const [],
            flags: const {},
            contract: CliContract.standard,
          ),
        );
        expect(result, isA<SuccessResult>());
        expect(
          (result as SuccessResult).data['users'],
          equals(['alice', 'bob']),
        );
        expect(container.lookups, contains('UserRepository'));
      });
    });

    group('binding failure (FR-007, FR-009)', () {
      test('U37: missing dependency throws BindingException', () async {
        final container = FakeDiContainer();
        // Note: no UserRepository registered.

        final shared = SharedCommand.of(
          StandardCommand(
            name: 'list-users',
            description: 'list users',
            handler: (_) async => const SuccessResult(),
          ),
          version: '1.0.0',
        );

        final binding = DiBinding.forHandler(
          dependencies: const [
            DependencyRequest(
              name: 'UserRepository',
              expectedType: UserRepository,
            ),
          ],
          boundHandler: (_) async => const SuccessResult(),
        );

        final bound = binding.bind(shared, container: container);
        late BindingException err;
        try {
          await bound.handler(
            CliInvocation(
              arguments: const [],
              flags: const {},
              contract: CliContract.standard,
            ),
          );
          fail('expected BindingException');
        } on BindingException catch (e) {
          err = e;
        }
        expect(err.commandName, equals('list-users'));
        expect(err.dependencyName, equals('UserRepository'));
        expect(err.reason, contains('not registered'));
      });

      test('type mismatch throws BindingException', () async {
        final container = FakeDiContainer();
        // Register the wrong type under the expected name.
        container.register<String>('UserRepository', 'not-a-repo');

        final shared = SharedCommand.of(
          StandardCommand(
            name: 'list-users',
            description: '',
            handler: (_) async => const SuccessResult(),
          ),
          version: '1.0.0',
        );

        final binding = DiBinding.forHandler(
          dependencies: const [
            DependencyRequest(
              name: 'UserRepository',
              expectedType: UserRepository,
            ),
          ],
          boundHandler: (_) async => const SuccessResult(),
        );

        final bound = binding.bind(shared, container: container);
        late BindingException err;
        try {
          await bound.handler(
            CliInvocation(
              arguments: const [],
              flags: const {},
              contract: CliContract.standard,
            ),
          );
          fail('expected BindingException');
        } on BindingException catch (e) {
          err = e;
        }
        expect(err.dependencyName, equals('UserRepository'));
        expect(err.reason, contains('expected'));
        expect(err.reason, contains('got'));
      });
    });
  });
}

// Test fixtures — pure-Dart, no Flutter.
abstract class UserRepository {
  List<String> all();
}

class UserRepositoryImpl implements UserRepository {
  @override
  List<String> all() => const ['alice', 'bob'];
}
