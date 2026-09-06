// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/grocery_item/grocery_item_remote_datasource.dart';
import '../../data/repositories/data_grocery_item_repository.dart';
import '../../domain/repositories/grocery_item_repository.dart';

void registerGroceryItemRepository(GetIt getIt) {
  getIt.registerLazySingleton<GroceryItemRepository>(
    () => DataGroceryItemRepository(getIt<GroceryItemRemoteDataSource>()),
  );
}

// END GENERATED
