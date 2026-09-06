// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/auth_request/auth_request_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/auth_request/auth_request_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/auth_request_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_auth_request_repository.dart';
import 'package:zikzak_demo/src/domain/entities/auth_request/auth_request.dart';
import 'package:zikzak_demo/src/domain/repositories/auth_request_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/auth_request/update_auth_request_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingAuthRequestDataSource
    with Loggable, FailureHandler
    implements AuthRequestDataSource {
  @override
  Future<AuthRequest> get(QueryParams<AuthRequest> params) {
    throw (Exception('ThrowingAuthRequestDataSource.get'));
  }

  @override
  Future<List<AuthRequest>> getList(ListQueryParams<AuthRequest> params) {
    throw (Exception('ThrowingAuthRequestDataSource.getList'));
  }

  @override
  Future<AuthRequest> create(AuthRequest entity) {
    throw (Exception('ThrowingAuthRequestDataSource.create'));
  }

  @override
  Future<AuthRequest> update(UpdateParams<String, AuthRequestPatch> params) {
    throw (Exception('ThrowingAuthRequestDataSource.update'));
  }

  @override
  Future<AuthRequest> toggle(
    ToggleParams<String, Field<AuthRequest, dynamic>> params,
  ) {
    throw (Exception('ThrowingAuthRequestDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingAuthRequestDataSource.delete'));
  }

  @override
  Stream<AuthRequest> watch(QueryParams<AuthRequest> params) {
    throw (Exception('ThrowingAuthRequestDataSource.watch'));
  }

  @override
  Stream<List<AuthRequest>> watchList(ListQueryParams<AuthRequest> params) {
    throw (Exception('ThrowingAuthRequestDataSource.watchList'));
  }
}

void main() {
  late UpdateAuthRequestUseCase useCase;
  late UpdateAuthRequestUseCase throwingUseCase;
  late DataAuthRequestRepository repository;
  late DataAuthRequestRepository throwingRepository;
  late AuthRequestMockDataSource mockDataSource;
  late ThrowingAuthRequestDataSource throwingDataSource;
  setUp(() {
    mockDataSource = AuthRequestMockDataSource();
    throwingDataSource = ThrowingAuthRequestDataSource();
    repository = DataAuthRequestRepository(mockDataSource);
    throwingRepository = DataAuthRequestRepository(throwingDataSource);
    useCase = UpdateAuthRequestUseCase(repository);
    throwingUseCase = UpdateAuthRequestUseCase(throwingRepository);
  });
  group('UpdateAuthRequestUseCase', () {
    final tAuthRequest = AuthRequestMockData.sampleAuthRequest;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, AuthRequestPatch>(
          id: tAuthRequest.email,
          data: AuthRequestPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, AuthRequestPatch>(
          id: tAuthRequest.email,
          data: AuthRequestPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
