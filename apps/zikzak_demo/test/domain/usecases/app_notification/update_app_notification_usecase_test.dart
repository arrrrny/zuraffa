// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/app_notification/app_notification_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/app_notification/app_notification_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/app_notification_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_app_notification_repository.dart';
import 'package:zikzak_demo/src/domain/entities/app_notification/app_notification.dart';
import 'package:zikzak_demo/src/domain/repositories/app_notification_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/app_notification/update_app_notification_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingAppNotificationDataSource
    with Loggable, FailureHandler
    implements AppNotificationDataSource {
  @override
  Future<AppNotification> get(QueryParams<AppNotification> params) {
    throw (Exception('ThrowingAppNotificationDataSource.get'));
  }

  @override
  Future<List<AppNotification>> getList(
    ListQueryParams<AppNotification> params,
  ) {
    throw (Exception('ThrowingAppNotificationDataSource.getList'));
  }

  @override
  Future<AppNotification> create(AppNotification entity) {
    throw (Exception('ThrowingAppNotificationDataSource.create'));
  }

  @override
  Future<AppNotification> update(
    UpdateParams<String, AppNotificationPatch> params,
  ) {
    throw (Exception('ThrowingAppNotificationDataSource.update'));
  }

  @override
  Future<AppNotification> toggle(
    ToggleParams<String, Field<AppNotification, dynamic>> params,
  ) {
    throw (Exception('ThrowingAppNotificationDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingAppNotificationDataSource.delete'));
  }

  @override
  Stream<AppNotification> watch(QueryParams<AppNotification> params) {
    throw (Exception('ThrowingAppNotificationDataSource.watch'));
  }

  @override
  Stream<List<AppNotification>> watchList(
    ListQueryParams<AppNotification> params,
  ) {
    throw (Exception('ThrowingAppNotificationDataSource.watchList'));
  }
}

void main() {
  late UpdateAppNotificationUseCase useCase;
  late UpdateAppNotificationUseCase throwingUseCase;
  late DataAppNotificationRepository repository;
  late DataAppNotificationRepository throwingRepository;
  late AppNotificationMockDataSource mockDataSource;
  late ThrowingAppNotificationDataSource throwingDataSource;
  setUp(() {
    mockDataSource = AppNotificationMockDataSource();
    throwingDataSource = ThrowingAppNotificationDataSource();
    repository = DataAppNotificationRepository(mockDataSource);
    throwingRepository = DataAppNotificationRepository(throwingDataSource);
    useCase = UpdateAppNotificationUseCase(repository);
    throwingUseCase = UpdateAppNotificationUseCase(throwingRepository);
  });
  group('UpdateAppNotificationUseCase', () {
    final tAppNotification = AppNotificationMockData.sampleAppNotification;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, AppNotificationPatch>(
          id: tAppNotification.id,
          data: AppNotificationPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, AppNotificationPatch>(
          id: tAppNotification.id,
          data: AppNotificationPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
