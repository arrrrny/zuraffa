// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/barcode_spark/barcode_spark_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/barcode_spark/barcode_spark_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/barcode_spark_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_barcode_spark_repository.dart';
import 'package:zikzak_demo/src/domain/entities/barcode_spark/barcode_spark.dart';
import 'package:zikzak_demo/src/domain/repositories/barcode_spark_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/barcode_spark/get_barcode_spark_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingBarcodeSparkDataSource
    with Loggable, FailureHandler
    implements BarcodeSparkDataSource {
  @override
  Future<BarcodeSpark> get(QueryParams<BarcodeSpark> params) {
    throw (Exception('ThrowingBarcodeSparkDataSource.get'));
  }

  @override
  Future<List<BarcodeSpark>> getList(ListQueryParams<BarcodeSpark> params) {
    throw (Exception('ThrowingBarcodeSparkDataSource.getList'));
  }

  @override
  Future<BarcodeSpark> create(BarcodeSpark entity) {
    throw (Exception('ThrowingBarcodeSparkDataSource.create'));
  }

  @override
  Future<BarcodeSpark> update(UpdateParams<String, BarcodeSparkPatch> params) {
    throw (Exception('ThrowingBarcodeSparkDataSource.update'));
  }

  @override
  Future<BarcodeSpark> toggle(
    ToggleParams<String, Field<BarcodeSpark, dynamic>> params,
  ) {
    throw (Exception('ThrowingBarcodeSparkDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingBarcodeSparkDataSource.delete'));
  }

  @override
  Stream<BarcodeSpark> watch(QueryParams<BarcodeSpark> params) {
    throw (Exception('ThrowingBarcodeSparkDataSource.watch'));
  }

  @override
  Stream<List<BarcodeSpark>> watchList(ListQueryParams<BarcodeSpark> params) {
    throw (Exception('ThrowingBarcodeSparkDataSource.watchList'));
  }
}

void main() {
  late GetBarcodeSparkUseCase useCase;
  late GetBarcodeSparkUseCase throwingUseCase;
  late DataBarcodeSparkRepository repository;
  late DataBarcodeSparkRepository throwingRepository;
  late BarcodeSparkMockDataSource mockDataSource;
  late ThrowingBarcodeSparkDataSource throwingDataSource;
  setUp(() {
    mockDataSource = BarcodeSparkMockDataSource();
    throwingDataSource = ThrowingBarcodeSparkDataSource();
    repository = DataBarcodeSparkRepository(mockDataSource);
    throwingRepository = DataBarcodeSparkRepository(throwingDataSource);
    useCase = GetBarcodeSparkUseCase(repository);
    throwingUseCase = GetBarcodeSparkUseCase(throwingRepository);
  });
  group('GetBarcodeSparkUseCase', () {
    final tBarcodeSpark = BarcodeSparkMockData.sampleBarcodeSpark;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<BarcodeSpark>(
          filter: Eq(BarcodeSparkFields.id, tBarcodeSpark.id),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tBarcodeSpark),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<BarcodeSpark>(
          filter: Eq(BarcodeSparkFields.id, tBarcodeSpark.id),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
