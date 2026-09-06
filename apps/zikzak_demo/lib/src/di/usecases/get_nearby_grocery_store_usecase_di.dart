// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/nearby_grocery_store_repository.dart';
import '../../domain/usecases/nearby_grocery_store/get_nearby_grocery_store_usecase.dart';

void registerGetNearbyGroceryStoreUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetNearbyGroceryStoreUseCase>(
    () => GetNearbyGroceryStoreUseCase(getIt<NearbyGroceryStoreRepository>()),
  );
}

// END GENERATED
