// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/barcode_listing/barcode_listing_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/barcode_listing/barcode_listing_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/barcode_listing_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_barcode_listing_repository.dart';
import 'package:zikzak_demo/src/domain/entities/barcode_listing/barcode_listing.dart';
import 'package:zikzak_demo/src/domain/repositories/barcode_listing_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/barcode_listing/toggle_barcode_listing_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingBarcodeListingDataSource
    with Loggable, FailureHandler
    implements BarcodeListingDataSource {
  @override
  Future<BarcodeListing> get(QueryParams<BarcodeListing> params) {
    throw (Exception('ThrowingBarcodeListingDataSource.get'));
  }

  @override
  Future<List<BarcodeListing>> getList(ListQueryParams<BarcodeListing> params) {
    throw (Exception('ThrowingBarcodeListingDataSource.getList'));
  }

  @override
  Future<BarcodeListing> create(BarcodeListing entity) {
    throw (Exception('ThrowingBarcodeListingDataSource.create'));
  }

  @override
  Future<BarcodeListing> update(
    UpdateParams<String, BarcodeListingPatch> params,
  ) {
    throw (Exception('ThrowingBarcodeListingDataSource.update'));
  }

  @override
  Future<BarcodeListing> toggle(
    ToggleParams<String, Field<BarcodeListing, dynamic>> params,
  ) {
    throw (Exception('ThrowingBarcodeListingDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingBarcodeListingDataSource.delete'));
  }

  @override
  Stream<BarcodeListing> watch(QueryParams<BarcodeListing> params) {
    throw (Exception('ThrowingBarcodeListingDataSource.watch'));
  }

  @override
  Stream<List<BarcodeListing>> watchList(
    ListQueryParams<BarcodeListing> params,
  ) {
    throw (Exception('ThrowingBarcodeListingDataSource.watchList'));
  }
}

void main() {
  late ToggleBarcodeListingUseCase useCase;
  late ToggleBarcodeListingUseCase throwingUseCase;
  late DataBarcodeListingRepository repository;
  late DataBarcodeListingRepository throwingRepository;
  late BarcodeListingMockDataSource mockDataSource;
  late ThrowingBarcodeListingDataSource throwingDataSource;
  setUp(() {
    mockDataSource = BarcodeListingMockDataSource();
    throwingDataSource = ThrowingBarcodeListingDataSource();
    repository = DataBarcodeListingRepository(mockDataSource);
    throwingRepository = DataBarcodeListingRepository(throwingDataSource);
    useCase = ToggleBarcodeListingUseCase(repository);
    throwingUseCase = ToggleBarcodeListingUseCase(throwingRepository);
  });
  group('ToggleBarcodeListingUseCase', () {
    final tBarcodeListing = BarcodeListingMockData.sampleBarcodeListing;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<BarcodeListing, dynamic>>(
          id: tBarcodeListing.id,
          field: BarcodeListingFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<BarcodeListing, dynamic>>(
          id: tBarcodeListing.id,
          field: BarcodeListingFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
