// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/listing_offer/listing_offer_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/listing_offer/listing_offer_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/listing_offer_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_listing_offer_repository.dart';
import 'package:zikzak_demo/src/domain/entities/listing_offer/listing_offer.dart';
import 'package:zikzak_demo/src/domain/repositories/listing_offer_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/listing_offer/get_listing_offer_usecase.dart';
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
  late GetListingOfferUseCase useCase;
  late GetListingOfferUseCase throwingUseCase;
  late DataListingOfferRepository repository;
  late DataListingOfferRepository throwingRepository;
  late ListingOfferMockDataSource mockDataSource;
  late ThrowingListingOfferDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ListingOfferMockDataSource();
    throwingDataSource = ThrowingListingOfferDataSource();
    repository = DataListingOfferRepository(mockDataSource);
    throwingRepository = DataListingOfferRepository(throwingDataSource);
    useCase = GetListingOfferUseCase(repository);
    throwingUseCase = GetListingOfferUseCase(throwingRepository);
  });
  group('GetListingOfferUseCase', () {
    final tListingOffer = ListingOfferMockData.sampleListingOffer;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<ListingOffer>(
          filter: Eq(ListingOfferFields.id, tListingOffer.id),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tListingOffer),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<ListingOffer>(
          filter: Eq(ListingOfferFields.id, tListingOffer.id),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
