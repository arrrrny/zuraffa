// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/locale/locale_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/locale/locale_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/locale_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_locale_repository.dart';
import 'package:zikzak_demo/src/domain/entities/locale/locale.dart';
import 'package:zikzak_demo/src/domain/repositories/locale_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/locale/get_locale_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingLocaleDataSource
    with Loggable, FailureHandler
    implements LocaleDataSource {
  @override
  Future<Locale> get(QueryParams<Locale> params) {
    throw (Exception('ThrowingLocaleDataSource.get'));
  }

  @override
  Future<List<Locale>> getList(ListQueryParams<Locale> params) {
    throw (Exception('ThrowingLocaleDataSource.getList'));
  }

  @override
  Future<Locale> create(Locale entity) {
    throw (Exception('ThrowingLocaleDataSource.create'));
  }

  @override
  Future<Locale> update(UpdateParams<String, LocalePatch> params) {
    throw (Exception('ThrowingLocaleDataSource.update'));
  }

  @override
  Future<Locale> toggle(ToggleParams<String, Field<Locale, dynamic>> params) {
    throw (Exception('ThrowingLocaleDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingLocaleDataSource.delete'));
  }

  @override
  Stream<Locale> watch(QueryParams<Locale> params) {
    throw (Exception('ThrowingLocaleDataSource.watch'));
  }

  @override
  Stream<List<Locale>> watchList(ListQueryParams<Locale> params) {
    throw (Exception('ThrowingLocaleDataSource.watchList'));
  }
}

void main() {
  late GetLocaleUseCase useCase;
  late GetLocaleUseCase throwingUseCase;
  late DataLocaleRepository repository;
  late DataLocaleRepository throwingRepository;
  late LocaleMockDataSource mockDataSource;
  late ThrowingLocaleDataSource throwingDataSource;
  setUp(() {
    mockDataSource = LocaleMockDataSource();
    throwingDataSource = ThrowingLocaleDataSource();
    repository = DataLocaleRepository(mockDataSource);
    throwingRepository = DataLocaleRepository(throwingDataSource);
    useCase = GetLocaleUseCase(repository);
    throwingUseCase = GetLocaleUseCase(throwingRepository);
  });
  group('GetLocaleUseCase', () {
    final tLocale = LocaleMockData.sampleLocale;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<Locale>(filter: Eq(LocaleFields.id, tLocale.id)),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tLocale),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<Locale>(filter: Eq(LocaleFields.id, tLocale.id)),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
