// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/listing/listing_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/listing/listing_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/listing_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_listing_repository.dart';
import 'package:zikzak_demo/src/domain/entities/listing/listing.dart';
import 'package:zikzak_demo/src/domain/repositories/listing_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/listing/toggle_listing_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingListingDataSource
    with Loggable, FailureHandler
    implements ListingDataSource {
  @override
  Future<Listing> get(QueryParams<Listing> params) {
    throw (Exception('ThrowingListingDataSource.get'));
  }

  @override
  Future<List<Listing>> getList(ListQueryParams<Listing> params) {
    throw (Exception('ThrowingListingDataSource.getList'));
  }

  @override
  Future<Listing> create(Listing entity) {
    throw (Exception('ThrowingListingDataSource.create'));
  }

  @override
  Future<Listing> update(UpdateParams<String, ListingPatch> params) {
    throw (Exception('ThrowingListingDataSource.update'));
  }

  @override
  Future<Listing> toggle(ToggleParams<String, Field<Listing, dynamic>> params) {
    throw (Exception('ThrowingListingDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingListingDataSource.delete'));
  }

  @override
  Stream<Listing> watch(QueryParams<Listing> params) {
    throw (Exception('ThrowingListingDataSource.watch'));
  }

  @override
  Stream<List<Listing>> watchList(ListQueryParams<Listing> params) {
    throw (Exception('ThrowingListingDataSource.watchList'));
  }
}

void main() {
  late ToggleListingUseCase useCase;
  late ToggleListingUseCase throwingUseCase;
  late DataListingRepository repository;
  late DataListingRepository throwingRepository;
  late ListingMockDataSource mockDataSource;
  late ThrowingListingDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ListingMockDataSource();
    throwingDataSource = ThrowingListingDataSource();
    repository = DataListingRepository(mockDataSource);
    throwingRepository = DataListingRepository(throwingDataSource);
    useCase = ToggleListingUseCase(repository);
    throwingUseCase = ToggleListingUseCase(throwingRepository);
  });
  group('ToggleListingUseCase', () {
    final tListing = ListingMockData.sampleListing;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<Listing, dynamic>>(
          id: tListing.id,
          field: ListingFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<Listing, dynamic>>(
          id: tListing.id,
          field: ListingFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
