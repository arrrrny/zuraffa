// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/grocery_store/grocery_store_remote_datasource.dart';
import '../../data/repositories/data_grocery_store_repository.dart';
import '../../domain/repositories/grocery_store_repository.dart';

void registerGroceryStoreRepository(GetIt getIt) {
  getIt.registerLazySingleton<GroceryStoreRepository>(
    () => DataGroceryStoreRepository(getIt<GroceryStoreRemoteDataSource>()),
  );
}

// END GENERATED
