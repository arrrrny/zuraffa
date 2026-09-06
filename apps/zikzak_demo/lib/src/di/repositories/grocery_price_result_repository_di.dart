// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/grocery_price_result/grocery_price_result_remote_datasource.dart';
import '../../data/repositories/data_grocery_price_result_repository.dart';
import '../../domain/repositories/grocery_price_result_repository.dart';

void registerGroceryPriceResultRepository(GetIt getIt) {
  getIt.registerLazySingleton<GroceryPriceResultRepository>(
    () => DataGroceryPriceResultRepository(
      getIt<GroceryPriceResultRemoteDataSource>(),
    ),
  );
}

// END GENERATED
