// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/subscription_repository.dart';
import '../../domain/usecases/subscription/update_subscription_usecase.dart';

void registerUpdateSubscriptionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateSubscriptionUseCase>(
    () => UpdateSubscriptionUseCase(getIt<SubscriptionRepository>()),
  );
}

// END GENERATED
