// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/authentication/authentication_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/authentication/authentication_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/authentication_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_authentication_repository.dart';
import 'package:zikzak_demo/src/domain/entities/authentication/authentication.dart';
import 'package:zikzak_demo/src/domain/repositories/authentication_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/authentication/toggle_authentication_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingAuthenticationDataSource
    with Loggable, FailureHandler
    implements AuthenticationDataSource {
  @override
  Future<Authentication> get(QueryParams<Authentication> params) {
    throw (Exception('ThrowingAuthenticationDataSource.get'));
  }

  @override
  Future<List<Authentication>> getList(ListQueryParams<Authentication> params) {
    throw (Exception('ThrowingAuthenticationDataSource.getList'));
  }

  @override
  Future<Authentication> create(Authentication entity) {
    throw (Exception('ThrowingAuthenticationDataSource.create'));
  }

  @override
  Future<Authentication> update(
    UpdateParams<String, AuthenticationPatch> params,
  ) {
    throw (Exception('ThrowingAuthenticationDataSource.update'));
  }

  @override
  Future<Authentication> toggle(
    ToggleParams<String, Field<Authentication, dynamic>> params,
  ) {
    throw (Exception('ThrowingAuthenticationDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingAuthenticationDataSource.delete'));
  }

  @override
  Stream<Authentication> watch(QueryParams<Authentication> params) {
    throw (Exception('ThrowingAuthenticationDataSource.watch'));
  }

  @override
  Stream<List<Authentication>> watchList(
    ListQueryParams<Authentication> params,
  ) {
    throw (Exception('ThrowingAuthenticationDataSource.watchList'));
  }
}

void main() {
  late ToggleAuthenticationUseCase useCase;
  late ToggleAuthenticationUseCase throwingUseCase;
  late DataAuthenticationRepository repository;
  late DataAuthenticationRepository throwingRepository;
  late AuthenticationMockDataSource mockDataSource;
  late ThrowingAuthenticationDataSource throwingDataSource;
  setUp(() {
    mockDataSource = AuthenticationMockDataSource();
    throwingDataSource = ThrowingAuthenticationDataSource();
    repository = DataAuthenticationRepository(mockDataSource);
    throwingRepository = DataAuthenticationRepository(throwingDataSource);
    useCase = ToggleAuthenticationUseCase(repository);
    throwingUseCase = ToggleAuthenticationUseCase(throwingRepository);
  });
  group('ToggleAuthenticationUseCase', () {
    final tAuthentication = AuthenticationMockData.sampleAuthentication;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<Authentication, dynamic>>(
          id: tAuthentication.id,
          field: AuthenticationFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<Authentication, dynamic>>(
          id: tAuthentication.id,
          field: AuthenticationFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
