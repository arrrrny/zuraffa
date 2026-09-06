// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/url_listing/url_listing_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/url_listing/url_listing_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/url_listing_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_url_listing_repository.dart';
import 'package:zikzak_demo/src/domain/entities/url_listing/url_listing.dart';
import 'package:zikzak_demo/src/domain/repositories/url_listing_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/url_listing/toggle_url_listing_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingUrlListingDataSource
    with Loggable, FailureHandler
    implements UrlListingDataSource {
  @override
  Future<UrlListing> get(QueryParams<UrlListing> params) {
    throw (Exception('ThrowingUrlListingDataSource.get'));
  }

  @override
  Future<List<UrlListing>> getList(ListQueryParams<UrlListing> params) {
    throw (Exception('ThrowingUrlListingDataSource.getList'));
  }

  @override
  Future<UrlListing> create(UrlListing entity) {
    throw (Exception('ThrowingUrlListingDataSource.create'));
  }

  @override
  Future<UrlListing> update(UpdateParams<String, UrlListingPatch> params) {
    throw (Exception('ThrowingUrlListingDataSource.update'));
  }

  @override
  Future<UrlListing> toggle(
    ToggleParams<String, Field<UrlListing, dynamic>> params,
  ) {
    throw (Exception('ThrowingUrlListingDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingUrlListingDataSource.delete'));
  }

  @override
  Stream<UrlListing> watch(QueryParams<UrlListing> params) {
    throw (Exception('ThrowingUrlListingDataSource.watch'));
  }

  @override
  Stream<List<UrlListing>> watchList(ListQueryParams<UrlListing> params) {
    throw (Exception('ThrowingUrlListingDataSource.watchList'));
  }
}

void main() {
  late ToggleUrlListingUseCase useCase;
  late ToggleUrlListingUseCase throwingUseCase;
  late DataUrlListingRepository repository;
  late DataUrlListingRepository throwingRepository;
  late UrlListingMockDataSource mockDataSource;
  late ThrowingUrlListingDataSource throwingDataSource;
  setUp(() {
    mockDataSource = UrlListingMockDataSource();
    throwingDataSource = ThrowingUrlListingDataSource();
    repository = DataUrlListingRepository(mockDataSource);
    throwingRepository = DataUrlListingRepository(throwingDataSource);
    useCase = ToggleUrlListingUseCase(repository);
    throwingUseCase = ToggleUrlListingUseCase(throwingRepository);
  });
  group('ToggleUrlListingUseCase', () {
    final tUrlListing = UrlListingMockData.sampleUrlListing;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<UrlListing, dynamic>>(
          id: tUrlListing.id,
          field: UrlListingFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<UrlListing, dynamic>>(
          id: tUrlListing.id,
          field: UrlListingFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
