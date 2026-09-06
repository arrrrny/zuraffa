// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/nearby_grocery_store_repository.dart';
import '../../domain/usecases/nearby_grocery_store/toggle_nearby_grocery_store_usecase.dart';

void registerToggleNearbyGroceryStoreUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleNearbyGroceryStoreUseCase>(
    () =>
        ToggleNearbyGroceryStoreUseCase(getIt<NearbyGroceryStoreRepository>()),
  );
}

// END GENERATED
