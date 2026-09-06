// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/text_listing/text_listing_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/text_listing/text_listing_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/text_listing_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_text_listing_repository.dart';
import 'package:zikzak_demo/src/domain/entities/text_listing/text_listing.dart';
import 'package:zikzak_demo/src/domain/repositories/text_listing_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/text_listing/get_text_listing_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingTextListingDataSource
    with Loggable, FailureHandler
    implements TextListingDataSource {
  @override
  Future<TextListing> get(QueryParams<TextListing> params) {
    throw (Exception('ThrowingTextListingDataSource.get'));
  }

  @override
  Future<List<TextListing>> getList(ListQueryParams<TextListing> params) {
    throw (Exception('ThrowingTextListingDataSource.getList'));
  }

  @override
  Future<TextListing> create(TextListing entity) {
    throw (Exception('ThrowingTextListingDataSource.create'));
  }

  @override
  Future<TextListing> update(UpdateParams<String, TextListingPatch> params) {
    throw (Exception('ThrowingTextListingDataSource.update'));
  }

  @override
  Future<TextListing> toggle(
    ToggleParams<String, Field<TextListing, dynamic>> params,
  ) {
    throw (Exception('ThrowingTextListingDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingTextListingDataSource.delete'));
  }

  @override
  Stream<TextListing> watch(QueryParams<TextListing> params) {
    throw (Exception('ThrowingTextListingDataSource.watch'));
  }

  @override
  Stream<List<TextListing>> watchList(ListQueryParams<TextListing> params) {
    throw (Exception('ThrowingTextListingDataSource.watchList'));
  }
}

void main() {
  late GetTextListingUseCase useCase;
  late GetTextListingUseCase throwingUseCase;
  late DataTextListingRepository repository;
  late DataTextListingRepository throwingRepository;
  late TextListingMockDataSource mockDataSource;
  late ThrowingTextListingDataSource throwingDataSource;
  setUp(() {
    mockDataSource = TextListingMockDataSource();
    throwingDataSource = ThrowingTextListingDataSource();
    repository = DataTextListingRepository(mockDataSource);
    throwingRepository = DataTextListingRepository(throwingDataSource);
    useCase = GetTextListingUseCase(repository);
    throwingUseCase = GetTextListingUseCase(throwingRepository);
  });
  group('GetTextListingUseCase', () {
    final tTextListing = TextListingMockData.sampleTextListing;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<TextListing>(
          filter: Eq(TextListingFields.id, tTextListing.id),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tTextListing),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<TextListing>(
          filter: Eq(TextListingFields.id, tTextListing.id),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
