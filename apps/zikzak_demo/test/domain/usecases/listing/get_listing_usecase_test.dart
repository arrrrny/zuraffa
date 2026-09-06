// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/listing/listing_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/listing/listing_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/listing_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_listing_repository.dart';
import 'package:zikzak_demo/src/domain/entities/listing/listing.dart';
import 'package:zikzak_demo/src/domain/repositories/listing_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/listing/get_listing_usecase.dart';
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
  late GetListingUseCase useCase;
  late GetListingUseCase throwingUseCase;
  late DataListingRepository repository;
  late DataListingRepository throwingRepository;
  late ListingMockDataSource mockDataSource;
  late ThrowingListingDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ListingMockDataSource();
    throwingDataSource = ThrowingListingDataSource();
    repository = DataListingRepository(mockDataSource);
    throwingRepository = DataListingRepository(throwingDataSource);
    useCase = GetListingUseCase(repository);
    throwingUseCase = GetListingUseCase(throwingRepository);
  });
  group('GetListingUseCase', () {
    final tListing = ListingMockData.sampleListing;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<Listing>(filter: Eq(ListingFields.id, tListing.id)),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tListing),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<Listing>(filter: Eq(ListingFields.id, tListing.id)),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
