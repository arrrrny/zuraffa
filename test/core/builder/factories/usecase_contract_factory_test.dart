import 'package:test/test.dart';
import 'package:code_builder/code_builder.dart';
import 'package:zuraffa/src/core/builder/factories/usecase_contract_factory.dart';
import 'package:zuraffa/src/core/builder/shared/spec_library.dart';

import 'package:test/test.dart' show isNot;

void main() {
  group('UseCaseContractFactory', () {
    late UseCaseContractFactory factory;

    setUp(() {
      factory = const UseCaseContractFactory();
    });

    group('buildContract', () {
      test('generates abstract contract class extending base class', () {
        final config = UseCaseContractSpecConfig(
          contractClassName: 'GetUserUseCase',
          implClassName: 'DefaultGetUserUseCase',
          baseClass: 'ZuraffaUseCase<User, String>',
          repositoryType: 'UserRepository',
          repositoryField: '_repository',
          returnType: 'User',
          paramsType: 'String',
          executeBody: 'return _repository.get(params);',
        );

        final library = factory.buildContract(config);
        final output = const SpecLibrary().emitLibrary(library);

        expect(output, contains('abstract class GetUserUseCase'));
        expect(output, contains('extends ZuraffaUseCase<User, String>'));
        expect(output, contains('// GENERATED - DO NOT EDIT'));
      });

      test('includes imports from config', () {
        final config = UseCaseContractSpecConfig(
          contractClassName: 'GetUserUseCase',
          implClassName: 'DefaultGetUserUseCase',
          baseClass: 'ZuraffaUseCase<User, String>',
          repositoryType: 'UserRepository',
          repositoryField: '_repository',
          returnType: 'User',
          paramsType: 'String',
          executeBody: 'return _repository.get(params);',
          imports: [
            "package:my_app/domain/user.dart",
            "package:my_app/repositories/user_repository.dart",
          ],
        );

        final library = factory.buildContract(config);
        final output = const SpecLibrary().emitLibrary(library);

        expect(output, contains("import 'package:my_app/domain/user.dart';"));
        expect(
          output,
          contains(
            "import 'package:my_app/repositories/user_repository.dart';",
          ),
        );
      });

      test('works with InterceptableUseCase as base class', () {
        final config = UseCaseContractSpecConfig(
          contractClassName: 'GetTodosUseCase',
          implClassName: 'DefaultGetTodosUseCase',
          baseClass: 'InterceptableUseCase<NoParams, List<Todo>>',
          repositoryType: 'TodoRepository',
          repositoryField: '_repository',
          returnType: 'List<Todo>',
          paramsType: 'NoParams',
          executeBody: 'return _repository.getAll();',
        );

        final library = factory.buildContract(config);
        final output = const SpecLibrary().emitLibrary(library);

        expect(output, contains('abstract class GetTodosUseCase'));
        expect(
          output,
          contains('extends InterceptableUseCase<NoParams, List<Todo>>'),
        );
      });
    });

    group('buildImpl', () {
      test('generates concrete implementation class extending contract', () {
        final config = UseCaseContractSpecConfig(
          contractClassName: 'GetUserUseCase',
          implClassName: 'DefaultGetUserUseCase',
          baseClass: 'ZuraffaUseCase<User, String>',
          repositoryType: 'UserRepository',
          repositoryField: '_repository',
          returnType: 'User',
          paramsType: 'String',
          executeBody: 'return _repository.get(params);',
          isAsync: true,
        );

        final library = factory.buildImpl(config);
        final output = const SpecLibrary().emitLibrary(library);

        expect(
          output,
          contains('class DefaultGetUserUseCase extends GetUserUseCase'),
        );
        expect(output, contains('final UserRepository _repository;'));
        expect(output, contains('DefaultGetUserUseCase(this._repository);'));
        expect(output, contains('User execute(String params) async'));
        expect(output, contains('return _repository.get(params);'));
      });

      test('generates constructor with repository field', () {
        final config = UseCaseContractSpecConfig(
          contractClassName: 'GetUserUseCase',
          implClassName: 'DefaultGetUserUseCase',
          baseClass: 'ZuraffaUseCase<User, String>',
          repositoryType: 'UserRepository',
          repositoryField: '_repo',
          returnType: 'User',
          paramsType: 'String',
          executeBody: 'return _repo.get(params);',
        );

        final library = factory.buildImpl(config);
        final output = const SpecLibrary().emitLibrary(library);

        expect(output, contains('final UserRepository _repo;'));
        expect(output, contains('DefaultGetUserUseCase(this._repo);'));
      });

      test('generates executeCall method when base is InterceptableUseCase', () {
        final config = UseCaseContractSpecConfig(
          contractClassName: 'GetTodosUseCase',
          implClassName: 'DefaultGetTodosUseCase',
          baseClass: 'InterceptableUseCase<NoParams, List<Todo>>',
          repositoryType: 'TodoRepository',
          repositoryField: '_repository',
          returnType: 'List<Todo>',
          paramsType: 'NoParams',
          executeBody: 'return _repository.getAll();',
        );

        final library = factory.buildImpl(config);
        final output = const SpecLibrary().emitLibrary(library);

        expect(
          output,
          contains('class DefaultGetTodosUseCase extends GetTodosUseCase'),
        );
        expect(
          output,
          contains(
            'List<Todo> executeCall(NoParams params, {ZuraffaContext? context}) async',
          ),
        );
        expect(output, contains('super.interceptorRegistry'));
      });

      test('generates execute method when base is ZuraffaUseCase', () {
        final config = UseCaseContractSpecConfig(
          contractClassName: 'GetUserUseCase',
          implClassName: 'DefaultGetUserUseCase',
          baseClass: 'ZuraffaUseCase<User, String>',
          repositoryType: 'UserRepository',
          repositoryField: '_repository',
          returnType: 'User',
          paramsType: 'String',
          executeBody: 'return _repository.get(params);',
        );

        final library = factory.buildImpl(config);
        final output = const SpecLibrary().emitLibrary(library);

        expect(output, contains('User execute(String params) async'));
        expect(output, isNot(contains('executeCall')));
        expect(output, isNot(contains('ZuraffaContext')));
        expect(output, isNot(contains('InterceptorRegistry')));
      });

      test('includes async body and proper return type', () {
        final config = UseCaseContractSpecConfig(
          contractClassName: 'CreateUserUseCase',
          implClassName: 'DefaultCreateUserUseCase',
          baseClass: 'ZuraffaUseCase<User, CreateUserParams>',
          repositoryType: 'UserRepository',
          repositoryField: '_repository',
          returnType: 'User',
          paramsType: 'CreateUserParams',
          executeBody: 'return _repository.create(params);',
          isAsync: true,
        );

        final library = factory.buildImpl(config);
        final output = const SpecLibrary().emitLibrary(library);

        expect(output, contains('User execute(CreateUserParams params) async'));
        expect(output, contains('return _repository.create(params);'));
      });

      test('includes imports from config in impl', () {
        final config = UseCaseContractSpecConfig(
          contractClassName: 'GetUserUseCase',
          implClassName: 'DefaultGetUserUseCase',
          baseClass: 'ZuraffaUseCase<User, String>',
          repositoryType: 'UserRepository',
          repositoryField: '_repository',
          returnType: 'User',
          paramsType: 'String',
          executeBody: 'return _repository.get(params);',
          imports: [
            "package:my_app/domain/user.dart",
            "package:my_app/repositories/user_repository.dart",
          ],
        );

        final library = factory.buildImpl(config);
        final output = const SpecLibrary().emitLibrary(library);

        expect(output, contains("import 'package:my_app/domain/user.dart';"));
        expect(
          output,
          contains(
            "import 'package:my_app/repositories/user_repository.dart';",
          ),
        );
      });

      test('handles hasParams = false correctly', () {
        final config = UseCaseContractSpecConfig(
          contractClassName: 'GetAllUsersUseCase',
          implClassName: 'DefaultGetAllUsersUseCase',
          baseClass: 'ZuraffaUseCase<List<User>, NoParams>',
          repositoryType: 'UserRepository',
          repositoryField: '_repository',
          returnType: 'List<User>',
          paramsType: 'NoParams',
          executeBody: 'return _repository.getAll();',
          hasParams: false,
        );

        final library = factory.buildImpl(config);
        final output = const SpecLibrary().emitLibrary(library);

        expect(output, contains('List<User> execute() async'));
      });

      test('handles sync (non-async) use case correctly', () {
        final config = UseCaseContractSpecConfig(
          contractClassName: 'GetCachedUserUseCase',
          implClassName: 'DefaultGetCachedUserUseCase',
          baseClass: 'ZuraffaUseCase<User, String>',
          repositoryType: 'UserRepository',
          repositoryField: '_repository',
          returnType: 'User',
          paramsType: 'String',
          executeBody: 'return _repository.getCached(params);',
          isAsync: false,
        );

        final library = factory.buildImpl(config);
        final output = const SpecLibrary().emitLibrary(library);

        expect(output, contains('User execute(String params)'));
        expect(output, isNot(contains('Future<')));
      });
    });
  });
}
