// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/grocery_price_comparison/grocery_price_comparison_remote_datasource.dart';
import '../../data/repositories/data_grocery_price_comparison_repository.dart';
import '../../domain/repositories/grocery_price_comparison_repository.dart';

void registerGroceryPriceComparisonRepository(GetIt getIt) {
  getIt.registerLazySingleton<GroceryPriceComparisonRepository>(
    () => DataGroceryPriceComparisonRepository(
      getIt<GroceryPriceComparisonRemoteDataSource>(),
    ),
  );
}

// END GENERATED
