/// Tests for RepositoryBuilder (042 working slice).
///
/// Behaviors traced to specs/042-bone-working-slice/tdd/test-list.md:
///   042-U16: abstract repository declares getById/getAll/save/delete
///   042-U17: abstract datasource interface mirrors the repository shape
///   042-U18: data implementation delegates to the injected datasource
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/builders/slice/repository_builder.dart';
import 'package:zuraffa/src/plugins/skeleton/models/bone.dart';

void main() {
  const userFields = [
    EntityField(name: 'id', type: 'String'),
    EntityField(name: 'displayName', type: 'String'),
    EntityField(name: 'email', type: 'String', nullable: true),
  ];

  group('RepositoryBuilder (042)', () {
    final builder = RepositoryBuilder();

    test(
      '042-U16: abstract repository declares getById/getAll/save/delete',
      () {
        final source = builder.buildRepositoryInterface('User', userFields);
        expect(source, contains('abstract class UserRepository'));
        expect(source, contains('Future<User?> getUserById(String id)'));
        expect(source, contains('Future<List<User>> getAllUsers()'));
        expect(source, contains('Future<void> saveUser(User instance)'));
        expect(source, contains('Future<void> deleteUser(String id)'));
      },
    );

    test('042-U17: abstract datasource interface mirrors repository shape', () {
      final source = builder.buildDataSourceInterface('User');
      expect(source, contains('abstract class UserDataSource'));
      expect(source, contains('Future<User?> getUserById(String id)'));
      expect(source, contains('Future<List<User>> getAllUsers()'));
      expect(source, contains('Future<void> saveUser(User instance)'));
      expect(source, contains('Future<void> deleteUser(String id)'));
      expect(source, contains("import '../../entities/user.dart'"));
    });

    test(
      '042-U18: data implementation delegates every method to the datasource',
      () {
        final source = builder.buildDataImplementation('User');
        expect(
          source,
          contains('class DataUserRepository implements UserRepository'),
        );
        expect(source, contains('const DataUserRepository(this.dataSource)'));
        expect(source, contains('final UserDataSource dataSource'));
        expect(source, contains('dataSource.getUserById(id)'));
        expect(source, contains('dataSource.getAllUsers()'));
        expect(source, contains('dataSource.saveUser(instance)'));
        expect(source, contains('dataSource.deleteUser(id)'));
      },
    );

    test('multi-word entity names produce snake_case paths', () {
      final source = builder.buildRepositoryInterface('CartItem', const []);
      expect(source, contains('abstract class CartItemRepository'));
      expect(source, contains('Future<CartItem?> getCartItemById(String id)'));
    });
  });
}
