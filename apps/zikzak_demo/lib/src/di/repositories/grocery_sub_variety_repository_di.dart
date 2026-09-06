// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/grocery_sub_variety/grocery_sub_variety_remote_datasource.dart';
import '../../data/repositories/data_grocery_sub_variety_repository.dart';
import '../../domain/repositories/grocery_sub_variety_repository.dart';

void registerGrocerySubVarietyRepository(GetIt getIt) {
  getIt.registerLazySingleton<GrocerySubVarietyRepository>(
    () => DataGrocerySubVarietyRepository(
      getIt<GrocerySubVarietyRemoteDataSource>(),
    ),
  );
}

// END GENERATED
