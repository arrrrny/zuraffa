// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/barcode/barcode_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/barcode/barcode_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/barcode_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_barcode_repository.dart';
import 'package:zikzak_demo/src/domain/entities/barcode/barcode.dart';
import 'package:zikzak_demo/src/domain/repositories/barcode_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/barcode/toggle_barcode_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingBarcodeDataSource
    with Loggable, FailureHandler
    implements BarcodeDataSource {
  @override
  Future<Barcode> get(QueryParams<Barcode> params) {
    throw (Exception('ThrowingBarcodeDataSource.get'));
  }

  @override
  Future<List<Barcode>> getList(ListQueryParams<Barcode> params) {
    throw (Exception('ThrowingBarcodeDataSource.getList'));
  }

  @override
  Future<Barcode> create(Barcode entity) {
    throw (Exception('ThrowingBarcodeDataSource.create'));
  }

  @override
  Future<Barcode> update(UpdateParams<String, BarcodePatch> params) {
    throw (Exception('ThrowingBarcodeDataSource.update'));
  }

  @override
  Future<Barcode> toggle(ToggleParams<String, Field<Barcode, dynamic>> params) {
    throw (Exception('ThrowingBarcodeDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingBarcodeDataSource.delete'));
  }

  @override
  Stream<Barcode> watch(QueryParams<Barcode> params) {
    throw (Exception('ThrowingBarcodeDataSource.watch'));
  }

  @override
  Stream<List<Barcode>> watchList(ListQueryParams<Barcode> params) {
    throw (Exception('ThrowingBarcodeDataSource.watchList'));
  }
}

void main() {
  late ToggleBarcodeUseCase useCase;
  late ToggleBarcodeUseCase throwingUseCase;
  late DataBarcodeRepository repository;
  late DataBarcodeRepository throwingRepository;
  late BarcodeMockDataSource mockDataSource;
  late ThrowingBarcodeDataSource throwingDataSource;
  setUp(() {
    mockDataSource = BarcodeMockDataSource();
    throwingDataSource = ThrowingBarcodeDataSource();
    repository = DataBarcodeRepository(mockDataSource);
    throwingRepository = DataBarcodeRepository(throwingDataSource);
    useCase = ToggleBarcodeUseCase(repository);
    throwingUseCase = ToggleBarcodeUseCase(throwingRepository);
  });
  group('ToggleBarcodeUseCase', () {
    final tBarcode = BarcodeMockData.sampleBarcode;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<Barcode, dynamic>>(
          id: tBarcode.value,
          field: BarcodeFields.value,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<Barcode, dynamic>>(
          id: tBarcode.value,
          field: BarcodeFields.value,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
