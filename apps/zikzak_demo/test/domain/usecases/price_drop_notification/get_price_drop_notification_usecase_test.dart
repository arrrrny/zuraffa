// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/price_drop_notification/price_drop_notification_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/price_drop_notification/price_drop_notification_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/price_drop_notification_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_price_drop_notification_repository.dart';
import 'package:zikzak_demo/src/domain/entities/price_drop_notification/price_drop_notification.dart';
import 'package:zikzak_demo/src/domain/repositories/price_drop_notification_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/price_drop_notification/get_price_drop_notification_usecase.dart';
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
  late GetPriceDropNotificationUseCase useCase;
  late GetPriceDropNotificationUseCase throwingUseCase;
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
    useCase = GetPriceDropNotificationUseCase(repository);
    throwingUseCase = GetPriceDropNotificationUseCase(throwingRepository);
  });
  group('GetPriceDropNotificationUseCase', () {
    final tPriceDropNotification =
        PriceDropNotificationMockData.samplePriceDropNotification;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<PriceDropNotification>(
          filter: Eq(PriceDropNotificationFields.id, tPriceDropNotification.id),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tPriceDropNotification),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<PriceDropNotification>(
          filter: Eq(PriceDropNotificationFields.id, tPriceDropNotification.id),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
