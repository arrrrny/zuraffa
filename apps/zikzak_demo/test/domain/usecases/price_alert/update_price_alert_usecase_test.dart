// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/price_alert/price_alert_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/price_alert/price_alert_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/price_alert_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_price_alert_repository.dart';
import 'package:zikzak_demo/src/domain/entities/price_alert/price_alert.dart';
import 'package:zikzak_demo/src/domain/repositories/price_alert_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/price_alert/update_price_alert_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingPriceAlertDataSource
    with Loggable, FailureHandler
    implements PriceAlertDataSource {
  @override
  Future<PriceAlert> get(QueryParams<PriceAlert> params) {
    throw (Exception('ThrowingPriceAlertDataSource.get'));
  }

  @override
  Future<List<PriceAlert>> getList(ListQueryParams<PriceAlert> params) {
    throw (Exception('ThrowingPriceAlertDataSource.getList'));
  }

  @override
  Future<PriceAlert> create(PriceAlert entity) {
    throw (Exception('ThrowingPriceAlertDataSource.create'));
  }

  @override
  Future<PriceAlert> update(UpdateParams<String, PriceAlertPatch> params) {
    throw (Exception('ThrowingPriceAlertDataSource.update'));
  }

  @override
  Future<PriceAlert> toggle(
    ToggleParams<String, Field<PriceAlert, dynamic>> params,
  ) {
    throw (Exception('ThrowingPriceAlertDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingPriceAlertDataSource.delete'));
  }

  @override
  Stream<PriceAlert> watch(QueryParams<PriceAlert> params) {
    throw (Exception('ThrowingPriceAlertDataSource.watch'));
  }

  @override
  Stream<List<PriceAlert>> watchList(ListQueryParams<PriceAlert> params) {
    throw (Exception('ThrowingPriceAlertDataSource.watchList'));
  }
}

void main() {
  late UpdatePriceAlertUseCase useCase;
  late UpdatePriceAlertUseCase throwingUseCase;
  late DataPriceAlertRepository repository;
  late DataPriceAlertRepository throwingRepository;
  late PriceAlertMockDataSource mockDataSource;
  late ThrowingPriceAlertDataSource throwingDataSource;
  setUp(() {
    mockDataSource = PriceAlertMockDataSource();
    throwingDataSource = ThrowingPriceAlertDataSource();
    repository = DataPriceAlertRepository(mockDataSource);
    throwingRepository = DataPriceAlertRepository(throwingDataSource);
    useCase = UpdatePriceAlertUseCase(repository);
    throwingUseCase = UpdatePriceAlertUseCase(throwingRepository);
  });
  group('UpdatePriceAlertUseCase', () {
    final tPriceAlert = PriceAlertMockData.samplePriceAlert;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, PriceAlertPatch>(
          id: tPriceAlert.id,
          data: PriceAlertPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, PriceAlertPatch>(
          id: tPriceAlert.id,
          data: PriceAlertPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
