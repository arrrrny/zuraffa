import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  test('UseCasePatterns builds usecase class', () {
    final execute = UseCasePatterns.executeMethod(
      returnType: 'Future<User>',
      paramsType: 'UserParams',
      body: 'return _repository.get(params);',
    );

    final clazz = UseCasePatterns.useCaseClass(
      className: 'GetUserUseCase',
      baseClass: 'UseCase<User, UserParams>',
      repositoryType: 'UserRepository',
      repositoryField: '_repository',
      executeMethod: execute,
    );

    final output = const SpecLibrary().emitSpec(clazz);
    expect(output.contains('class GetUserUseCase'), isTrue);
    expect(output.contains('Future<User> execute(UserParams params)'), isTrue);
    expect(output.contains('return _repository.get(params);'), isTrue);
  });
}
