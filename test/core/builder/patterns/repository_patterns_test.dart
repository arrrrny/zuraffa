import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:code_builder/code_builder.dart';

void main() {
  test('RepositoryPatterns builds repository interface', () {
    final method = RepositoryPatterns.repositoryMethod(
      name: 'get',
      returnType: 'Future<User>',
      parameters: [
        Parameter(
          (b) => b
            ..name = 'id'
            ..type = refer('String'),
        ),
      ],
    );
    final clazz = RepositoryPatterns.repositoryInterface(
      className: 'UserRepository',
      methods: [method],
    );

    final output = const SpecLibrary().emitSpec(clazz);
    expect(output.contains('abstract class UserRepository'), isTrue);
    expect(output.contains('Future<User> get(String id)'), isTrue);
  });
}
