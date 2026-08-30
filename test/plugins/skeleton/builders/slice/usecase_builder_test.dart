/// Tests for UseCaseBuilder (042 working slice).
///
/// Behaviors traced to specs/042-bone-working-slice/tdd/test-list.md:
///   042-U19: four CRUD use cases per entity; repo via constructor; call
///   delegates to the repository.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/builders/slice/usecase_builder.dart';

void main() {
  group('UseCaseBuilder (042)', () {
    final builder = UseCaseBuilder();

    test('042-U19: four use cases per entity; repository injected via '
        'constructor; call delegates', () {
      final sources = builder.buildAll('User');
      expect(sources, hasLength(4));
      expect(sources.keys, contains('get_user_usecase.dart'));
      expect(sources.keys, contains('create_user_usecase.dart'));
      expect(sources.keys, contains('update_user_usecase.dart'));
      expect(sources.keys, contains('delete_user_usecase.dart'));

      final get = sources['get_user_usecase.dart']!;
      expect(get, contains('class GetUserUseCase'));
      expect(get, contains('const GetUserUseCase(this.repository)'));
      expect(get, contains('final UserRepository repository'));
      expect(get, contains('Future<User?> call(String id)'));
      expect(get, contains('=> repository.getUserById(id)'));
      expect(get, contains("import '../repositories/user_repository.dart'"));

      final create = sources['create_user_usecase.dart']!;
      expect(create, contains('class CreateUserUseCase'));
      expect(create, contains('Future<void> call(User instance)'));
      expect(create, contains('=> repository.saveUser(instance)'));

      final update = sources['update_user_usecase.dart']!;
      expect(update, contains('class UpdateUserUseCase'));
      expect(update, contains('Future<void> call(User instance)'));
      expect(update, contains('=> repository.saveUser(instance)'));

      final delete = sources['delete_user_usecase.dart']!;
      expect(delete, contains('class DeleteUserUseCase'));
      expect(delete, contains('Future<void> call(String id)'));
      expect(delete, contains('=> repository.deleteUser(id)'));
    });

    test('multi-word entity names produce correct class + file names', () {
      final sources = builder.buildAll('CartItem');
      expect(sources.keys, contains('get_cart_item_usecase.dart'));
      expect(
        sources['get_cart_item_usecase.dart']!,
        contains('GetCartItemUseCase'),
      );
    });
  });
}
