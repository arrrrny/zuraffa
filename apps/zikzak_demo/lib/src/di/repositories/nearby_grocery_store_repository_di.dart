// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/nearby_grocery_store/nearby_grocery_store_remote_datasource.dart';
import '../../data/repositories/data_nearby_grocery_store_repository.dart';
import '../../domain/repositories/nearby_grocery_store_repository.dart';

void registerNearbyGroceryStoreRepository(GetIt getIt) {
  getIt.registerLazySingleton<NearbyGroceryStoreRepository>(
    () => DataNearbyGroceryStoreRepository(
      getIt<NearbyGroceryStoreRemoteDataSource>(),
    ),
  );
}

// END GENERATED
