// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/error_log/error_log_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/error_log/error_log_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/error_log_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_error_log_repository.dart';
import 'package:zikzak_demo/src/domain/entities/error_log/error_log.dart';
import 'package:zikzak_demo/src/domain/repositories/error_log_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/error_log/update_error_log_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingErrorLogDataSource
    with Loggable, FailureHandler
    implements ErrorLogDataSource {
  @override
  Future<ErrorLog> get(QueryParams<ErrorLog> params) {
    throw (Exception('ThrowingErrorLogDataSource.get'));
  }

  @override
  Future<List<ErrorLog>> getList(ListQueryParams<ErrorLog> params) {
    throw (Exception('ThrowingErrorLogDataSource.getList'));
  }

  @override
  Future<ErrorLog> create(ErrorLog entity) {
    throw (Exception('ThrowingErrorLogDataSource.create'));
  }

  @override
  Future<ErrorLog> update(UpdateParams<String, ErrorLogPatch> params) {
    throw (Exception('ThrowingErrorLogDataSource.update'));
  }

  @override
  Future<ErrorLog> toggle(
    ToggleParams<String, Field<ErrorLog, dynamic>> params,
  ) {
    throw (Exception('ThrowingErrorLogDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingErrorLogDataSource.delete'));
  }

  @override
  Stream<ErrorLog> watch(QueryParams<ErrorLog> params) {
    throw (Exception('ThrowingErrorLogDataSource.watch'));
  }

  @override
  Stream<List<ErrorLog>> watchList(ListQueryParams<ErrorLog> params) {
    throw (Exception('ThrowingErrorLogDataSource.watchList'));
  }
}

void main() {
  late UpdateErrorLogUseCase useCase;
  late UpdateErrorLogUseCase throwingUseCase;
  late DataErrorLogRepository repository;
  late DataErrorLogRepository throwingRepository;
  late ErrorLogMockDataSource mockDataSource;
  late ThrowingErrorLogDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ErrorLogMockDataSource();
    throwingDataSource = ThrowingErrorLogDataSource();
    repository = DataErrorLogRepository(mockDataSource);
    throwingRepository = DataErrorLogRepository(throwingDataSource);
    useCase = UpdateErrorLogUseCase(repository);
    throwingUseCase = UpdateErrorLogUseCase(throwingRepository);
  });
  group('UpdateErrorLogUseCase', () {
    final tErrorLog = ErrorLogMockData.sampleErrorLog;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, ErrorLogPatch>(
          id: tErrorLog.id,
          data: ErrorLogPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, ErrorLogPatch>(
          id: tErrorLog.id,
          data: ErrorLogPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
