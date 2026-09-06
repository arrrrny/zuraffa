// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/grocery_product/grocery_product_remote_datasource.dart';
import '../../data/repositories/data_grocery_product_repository.dart';
import '../../domain/repositories/grocery_product_repository.dart';

void registerGroceryProductRepository(GetIt getIt) {
  getIt.registerLazySingleton<GroceryProductRepository>(
    () => DataGroceryProductRepository(getIt<GroceryProductRemoteDataSource>()),
  );
}

// END GENERATED
