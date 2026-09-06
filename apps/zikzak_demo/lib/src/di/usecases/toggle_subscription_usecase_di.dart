// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/subscription_repository.dart';
import '../../domain/usecases/subscription/toggle_subscription_usecase.dart';

void registerToggleSubscriptionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleSubscriptionUseCase>(
    () => ToggleSubscriptionUseCase(getIt<SubscriptionRepository>()),
  );
}

// END GENERATED
