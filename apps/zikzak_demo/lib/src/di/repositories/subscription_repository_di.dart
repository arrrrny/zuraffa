// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/subscription/subscription_remote_datasource.dart';
import '../../data/repositories/data_subscription_repository.dart';
import '../../domain/repositories/subscription_repository.dart';

void registerSubscriptionRepository(GetIt getIt) {
  getIt.registerLazySingleton<SubscriptionRepository>(
    () => DataSubscriptionRepository(getIt<SubscriptionRemoteDataSource>()),
  );
}

// END GENERATED
