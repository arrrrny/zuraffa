// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/price_drop_notification/price_drop_notification_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/price_drop_notification/price_drop_notification_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/price_drop_notification_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_price_drop_notification_repository.dart';
import 'package:zikzak_demo/src/domain/entities/price_drop_notification/price_drop_notification.dart';
import 'package:zikzak_demo/src/domain/repositories/price_drop_notification_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/price_drop_notification/toggle_price_drop_notification_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingPriceDropNotificationDataSource
    with Loggable, FailureHandler
    implements PriceDropNotificationDataSource {
  @override
  Future<PriceDropNotification> get(QueryParams<PriceDropNotification> params) {
    throw (Exception('ThrowingPriceDropNotificationDataSource.get'));
  }

  @override
  Future<List<PriceDropNotification>> getList(
    ListQueryParams<PriceDropNotification> params,
  ) {
    throw (Exception('ThrowingPriceDropNotificationDataSource.getList'));
  }

  @override
  Future<PriceDropNotification> create(PriceDropNotification entity) {
    throw (Exception('ThrowingPriceDropNotificationDataSource.create'));
  }

  @override
  Future<PriceDropNotification> update(
    UpdateParams<String, PriceDropNotificationPatch> params,
  ) {
    throw (Exception('ThrowingPriceDropNotificationDataSource.update'));
  }

  @override
  Future<PriceDropNotification> toggle(
    ToggleParams<String, Field<PriceDropNotification, dynamic>> params,
  ) {
    throw (Exception('ThrowingPriceDropNotificationDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingPriceDropNotificationDataSource.delete'));
  }

  @override
  Stream<PriceDropNotification> watch(
    QueryParams<PriceDropNotification> params,
  ) {
    throw (Exception('ThrowingPriceDropNotificationDataSource.watch'));
  }

  @override
  Stream<List<PriceDropNotification>> watchList(
    ListQueryParams<PriceDropNotification> params,
  ) {
    throw (Exception('ThrowingPriceDropNotificationDataSource.watchList'));
  }
}

void main() {
  late TogglePriceDropNotificationUseCase useCase;
  late TogglePriceDropNotificationUseCase throwingUseCase;
  late DataPriceDropNotificationRepository repository;
  late DataPriceDropNotificationRepository throwingRepository;
  late PriceDropNotificationMockDataSource mockDataSource;
  late ThrowingPriceDropNotificationDataSource throwingDataSource;
  setUp(() {
    mockDataSource = PriceDropNotificationMockDataSource();
    throwingDataSource = ThrowingPriceDropNotificationDataSource();
    repository = DataPriceDropNotificationRepository(mockDataSource);
    throwingRepository = DataPriceDropNotificationRepository(
      throwingDataSource,
    );
    useCase = TogglePriceDropNotificationUseCase(repository);
    throwingUseCase = TogglePriceDropNotificationUseCase(throwingRepository);
  });
  group('TogglePriceDropNotificationUseCase', () {
    final tPriceDropNotification =
        PriceDropNotificationMockData.samplePriceDropNotification;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<PriceDropNotification, dynamic>>(
          id: tPriceDropNotification.id,
          field: PriceDropNotificationFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<PriceDropNotification, dynamic>>(
          id: tPriceDropNotification.id,
          field: PriceDropNotificationFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
