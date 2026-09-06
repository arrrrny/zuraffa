// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/url_spark/url_spark_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/url_spark/url_spark_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/url_spark_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_url_spark_repository.dart';
import 'package:zikzak_demo/src/domain/entities/url_spark/url_spark.dart';
import 'package:zikzak_demo/src/domain/repositories/url_spark_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/url_spark/toggle_url_spark_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingUrlSparkDataSource
    with Loggable, FailureHandler
    implements UrlSparkDataSource {
  @override
  Future<UrlSpark> get(QueryParams<UrlSpark> params) {
    throw (Exception('ThrowingUrlSparkDataSource.get'));
  }

  @override
  Future<List<UrlSpark>> getList(ListQueryParams<UrlSpark> params) {
    throw (Exception('ThrowingUrlSparkDataSource.getList'));
  }

  @override
  Future<UrlSpark> create(UrlSpark entity) {
    throw (Exception('ThrowingUrlSparkDataSource.create'));
  }

  @override
  Future<UrlSpark> update(UpdateParams<String, UrlSparkPatch> params) {
    throw (Exception('ThrowingUrlSparkDataSource.update'));
  }

  @override
  Future<UrlSpark> toggle(
    ToggleParams<String, Field<UrlSpark, dynamic>> params,
  ) {
    throw (Exception('ThrowingUrlSparkDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingUrlSparkDataSource.delete'));
  }

  @override
  Stream<UrlSpark> watch(QueryParams<UrlSpark> params) {
    throw (Exception('ThrowingUrlSparkDataSource.watch'));
  }

  @override
  Stream<List<UrlSpark>> watchList(ListQueryParams<UrlSpark> params) {
    throw (Exception('ThrowingUrlSparkDataSource.watchList'));
  }
}

void main() {
  late ToggleUrlSparkUseCase useCase;
  late ToggleUrlSparkUseCase throwingUseCase;
  late DataUrlSparkRepository repository;
  late DataUrlSparkRepository throwingRepository;
  late UrlSparkMockDataSource mockDataSource;
  late ThrowingUrlSparkDataSource throwingDataSource;
  setUp(() {
    mockDataSource = UrlSparkMockDataSource();
    throwingDataSource = ThrowingUrlSparkDataSource();
    repository = DataUrlSparkRepository(mockDataSource);
    throwingRepository = DataUrlSparkRepository(throwingDataSource);
    useCase = ToggleUrlSparkUseCase(repository);
    throwingUseCase = ToggleUrlSparkUseCase(throwingRepository);
  });
  group('ToggleUrlSparkUseCase', () {
    final tUrlSpark = UrlSparkMockData.sampleUrlSpark;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<UrlSpark, dynamic>>(
          id: tUrlSpark.id,
          field: UrlSparkFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<UrlSpark, dynamic>>(
          id: tUrlSpark.id,
          field: UrlSparkFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
