// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/nearby_grocery_store_repository.dart';
import '../../domain/usecases/nearby_grocery_store/update_nearby_grocery_store_usecase.dart';

void registerUpdateNearbyGroceryStoreUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateNearbyGroceryStoreUseCase>(
    () =>
        UpdateNearbyGroceryStoreUseCase(getIt<NearbyGroceryStoreRepository>()),
  );
}

// END GENERATED
