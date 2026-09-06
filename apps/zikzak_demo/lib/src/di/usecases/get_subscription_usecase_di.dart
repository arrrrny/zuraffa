// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/subscription_repository.dart';
import '../../domain/usecases/subscription/get_subscription_usecase.dart';

void registerGetSubscriptionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetSubscriptionUseCase>(
    () => GetSubscriptionUseCase(getIt<SubscriptionRepository>()),
  );
}

// END GENERATED
