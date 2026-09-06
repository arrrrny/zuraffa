// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/listing_offer/listing_offer_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/listing_offer/listing_offer_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/listing_offer_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_listing_offer_repository.dart';
import 'package:zikzak_demo/src/domain/entities/listing_offer/listing_offer.dart';
import 'package:zikzak_demo/src/domain/repositories/listing_offer_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/listing_offer/toggle_listing_offer_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingListingOfferDataSource
    with Loggable, FailureHandler
    implements ListingOfferDataSource {
  @override
  Future<ListingOffer> get(QueryParams<ListingOffer> params) {
    throw (Exception('ThrowingListingOfferDataSource.get'));
  }

  @override
  Future<List<ListingOffer>> getList(ListQueryParams<ListingOffer> params) {
    throw (Exception('ThrowingListingOfferDataSource.getList'));
  }

  @override
  Future<ListingOffer> create(ListingOffer entity) {
    throw (Exception('ThrowingListingOfferDataSource.create'));
  }

  @override
  Future<ListingOffer> update(UpdateParams<String, ListingOfferPatch> params) {
    throw (Exception('ThrowingListingOfferDataSource.update'));
  }

  @override
  Future<ListingOffer> toggle(
    ToggleParams<String, Field<ListingOffer, dynamic>> params,
  ) {
    throw (Exception('ThrowingListingOfferDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingListingOfferDataSource.delete'));
  }

  @override
  Stream<ListingOffer> watch(QueryParams<ListingOffer> params) {
    throw (Exception('ThrowingListingOfferDataSource.watch'));
  }

  @override
  Stream<List<ListingOffer>> watchList(ListQueryParams<ListingOffer> params) {
    throw (Exception('ThrowingListingOfferDataSource.watchList'));
  }
}

void main() {
  late ToggleListingOfferUseCase useCase;
  late ToggleListingOfferUseCase throwingUseCase;
  late DataListingOfferRepository repository;
  late DataListingOfferRepository throwingRepository;
  late ListingOfferMockDataSource mockDataSource;
  late ThrowingListingOfferDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ListingOfferMockDataSource();
    throwingDataSource = ThrowingListingOfferDataSource();
    repository = DataListingOfferRepository(mockDataSource);
    throwingRepository = DataListingOfferRepository(throwingDataSource);
    useCase = ToggleListingOfferUseCase(repository);
    throwingUseCase = ToggleListingOfferUseCase(throwingRepository);
  });
  group('ToggleListingOfferUseCase', () {
    final tListingOffer = ListingOfferMockData.sampleListingOffer;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<ListingOffer, dynamic>>(
          id: tListingOffer.id,
          field: ListingOfferFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<ListingOffer, dynamic>>(
          id: tListingOffer.id,
          field: ListingOfferFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
