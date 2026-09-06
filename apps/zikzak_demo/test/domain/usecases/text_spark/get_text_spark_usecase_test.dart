// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/text_spark/text_spark_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/text_spark/text_spark_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/text_spark_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_text_spark_repository.dart';
import 'package:zikzak_demo/src/domain/entities/text_spark/text_spark.dart';
import 'package:zikzak_demo/src/domain/repositories/text_spark_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/text_spark/get_text_spark_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingTextSparkDataSource
    with Loggable, FailureHandler
    implements TextSparkDataSource {
  @override
  Future<TextSpark> get(QueryParams<TextSpark> params) {
    throw (Exception('ThrowingTextSparkDataSource.get'));
  }

  @override
  Future<List<TextSpark>> getList(ListQueryParams<TextSpark> params) {
    throw (Exception('ThrowingTextSparkDataSource.getList'));
  }

  @override
  Future<TextSpark> create(TextSpark entity) {
    throw (Exception('ThrowingTextSparkDataSource.create'));
  }

  @override
  Future<TextSpark> update(UpdateParams<String, TextSparkPatch> params) {
    throw (Exception('ThrowingTextSparkDataSource.update'));
  }

  @override
  Future<TextSpark> toggle(
    ToggleParams<String, Field<TextSpark, dynamic>> params,
  ) {
    throw (Exception('ThrowingTextSparkDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingTextSparkDataSource.delete'));
  }

  @override
  Stream<TextSpark> watch(QueryParams<TextSpark> params) {
    throw (Exception('ThrowingTextSparkDataSource.watch'));
  }

  @override
  Stream<List<TextSpark>> watchList(ListQueryParams<TextSpark> params) {
    throw (Exception('ThrowingTextSparkDataSource.watchList'));
  }
}

void main() {
  late GetTextSparkUseCase useCase;
  late GetTextSparkUseCase throwingUseCase;
  late DataTextSparkRepository repository;
  late DataTextSparkRepository throwingRepository;
  late TextSparkMockDataSource mockDataSource;
  late ThrowingTextSparkDataSource throwingDataSource;
  setUp(() {
    mockDataSource = TextSparkMockDataSource();
    throwingDataSource = ThrowingTextSparkDataSource();
    repository = DataTextSparkRepository(mockDataSource);
    throwingRepository = DataTextSparkRepository(throwingDataSource);
    useCase = GetTextSparkUseCase(repository);
    throwingUseCase = GetTextSparkUseCase(throwingRepository);
  });
  group('GetTextSparkUseCase', () {
    final tTextSpark = TextSparkMockData.sampleTextSpark;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<TextSpark>(filter: Eq(TextSparkFields.id, tTextSpark.id)),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tTextSpark),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<TextSpark>(filter: Eq(TextSparkFields.id, tTextSpark.id)),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
