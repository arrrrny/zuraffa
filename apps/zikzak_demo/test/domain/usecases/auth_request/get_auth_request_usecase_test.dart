// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/auth_request/auth_request_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/auth_request/auth_request_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/auth_request_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_auth_request_repository.dart';
import 'package:zikzak_demo/src/domain/entities/auth_request/auth_request.dart';
import 'package:zikzak_demo/src/domain/repositories/auth_request_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/auth_request/get_auth_request_usecase.dart';
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
  late GetAuthRequestUseCase useCase;
  late GetAuthRequestUseCase throwingUseCase;
  late DataAuthRequestRepository repository;
  late DataAuthRequestRepository throwingRepository;
  late AuthRequestMockDataSource mockDataSource;
  late ThrowingAuthRequestDataSource throwingDataSource;
  setUp(() {
    mockDataSource = AuthRequestMockDataSource();
    throwingDataSource = ThrowingAuthRequestDataSource();
    repository = DataAuthRequestRepository(mockDataSource);
    throwingRepository = DataAuthRequestRepository(throwingDataSource);
    useCase = GetAuthRequestUseCase(repository);
    throwingUseCase = GetAuthRequestUseCase(throwingRepository);
  });
  group('GetAuthRequestUseCase', () {
    final tAuthRequest = AuthRequestMockData.sampleAuthRequest;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<AuthRequest>(
          filter: Eq(AuthRequestFields.email, tAuthRequest.email),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tAuthRequest),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<AuthRequest>(
          filter: Eq(AuthRequestFields.email, tAuthRequest.email),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
