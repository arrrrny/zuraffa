// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/subscription/subscription_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/subscription/subscription_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/subscription_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_subscription_repository.dart';
import 'package:zikzak_demo/src/domain/entities/subscription/subscription.dart';
import 'package:zikzak_demo/src/domain/repositories/subscription_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/subscription/toggle_subscription_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingSubscriptionDataSource
    with Loggable, FailureHandler
    implements SubscriptionDataSource {
  @override
  Future<Subscription> get(QueryParams<Subscription> params) {
    throw (Exception('ThrowingSubscriptionDataSource.get'));
  }

  @override
  Future<List<Subscription>> getList(ListQueryParams<Subscription> params) {
    throw (Exception('ThrowingSubscriptionDataSource.getList'));
  }

  @override
  Future<Subscription> create(Subscription entity) {
    throw (Exception('ThrowingSubscriptionDataSource.create'));
  }

  @override
  Future<Subscription> update(UpdateParams<String, SubscriptionPatch> params) {
    throw (Exception('ThrowingSubscriptionDataSource.update'));
  }

  @override
  Future<Subscription> toggle(
    ToggleParams<String, Field<Subscription, dynamic>> params,
  ) {
    throw (Exception('ThrowingSubscriptionDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingSubscriptionDataSource.delete'));
  }

  @override
  Stream<Subscription> watch(QueryParams<Subscription> params) {
    throw (Exception('ThrowingSubscriptionDataSource.watch'));
  }

  @override
  Stream<List<Subscription>> watchList(ListQueryParams<Subscription> params) {
    throw (Exception('ThrowingSubscriptionDataSource.watchList'));
  }
}

void main() {
  late ToggleSubscriptionUseCase useCase;
  late ToggleSubscriptionUseCase throwingUseCase;
  late DataSubscriptionRepository repository;
  late DataSubscriptionRepository throwingRepository;
  late SubscriptionMockDataSource mockDataSource;
  late ThrowingSubscriptionDataSource throwingDataSource;
  setUp(() {
    mockDataSource = SubscriptionMockDataSource();
    throwingDataSource = ThrowingSubscriptionDataSource();
    repository = DataSubscriptionRepository(mockDataSource);
    throwingRepository = DataSubscriptionRepository(throwingDataSource);
    useCase = ToggleSubscriptionUseCase(repository);
    throwingUseCase = ToggleSubscriptionUseCase(throwingRepository);
  });
  group('ToggleSubscriptionUseCase', () {
    final tSubscription = SubscriptionMockData.sampleSubscription;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<Subscription, dynamic>>(
          id: tSubscription.id,
          field: SubscriptionFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<Subscription, dynamic>>(
          id: tSubscription.id,
          field: SubscriptionFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
