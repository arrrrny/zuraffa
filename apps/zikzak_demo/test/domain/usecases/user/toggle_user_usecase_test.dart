// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/user/user_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/user/user_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/user_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_user_repository.dart';
import 'package:zikzak_demo/src/domain/entities/user/user.dart';
import 'package:zikzak_demo/src/domain/repositories/user_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/user/toggle_user_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingUserDataSource
    with Loggable, FailureHandler
    implements UserDataSource {
  @override
  Future<User> get(QueryParams<User> params) {
    throw (Exception('ThrowingUserDataSource.get'));
  }

  @override
  Future<List<User>> getList(ListQueryParams<User> params) {
    throw (Exception('ThrowingUserDataSource.getList'));
  }

  @override
  Future<User> create(User entity) {
    throw (Exception('ThrowingUserDataSource.create'));
  }

  @override
  Future<User> update(UpdateParams<String, UserPatch> params) {
    throw (Exception('ThrowingUserDataSource.update'));
  }

  @override
  Future<User> toggle(ToggleParams<String, Field<User, dynamic>> params) {
    throw (Exception('ThrowingUserDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingUserDataSource.delete'));
  }

  @override
  Stream<User> watch(QueryParams<User> params) {
    throw (Exception('ThrowingUserDataSource.watch'));
  }

  @override
  Stream<List<User>> watchList(ListQueryParams<User> params) {
    throw (Exception('ThrowingUserDataSource.watchList'));
  }
}

void main() {
  late ToggleUserUseCase useCase;
  late ToggleUserUseCase throwingUseCase;
  late DataUserRepository repository;
  late DataUserRepository throwingRepository;
  late UserMockDataSource mockDataSource;
  late ThrowingUserDataSource throwingDataSource;
  setUp(() {
    mockDataSource = UserMockDataSource();
    throwingDataSource = ThrowingUserDataSource();
    repository = DataUserRepository(mockDataSource);
    throwingRepository = DataUserRepository(throwingDataSource);
    useCase = ToggleUserUseCase(repository);
    throwingUseCase = ToggleUserUseCase(throwingRepository);
  });
  group('ToggleUserUseCase', () {
    final tUser = UserMockData.sampleUser;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<User, dynamic>>(
          id: tUser.id,
          field: UserFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<User, dynamic>>(
          id: tUser.id,
          field: UserFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
