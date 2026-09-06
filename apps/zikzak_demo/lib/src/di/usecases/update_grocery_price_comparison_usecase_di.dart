// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_price_comparison_repository.dart';
import '../../domain/usecases/grocery_price_comparison/update_grocery_price_comparison_usecase.dart';

void registerUpdateGroceryPriceComparisonUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateGroceryPriceComparisonUseCase>(
    () => UpdateGroceryPriceComparisonUseCase(
      getIt<GroceryPriceComparisonRepository>(),
    ),
  );
}

// END GENERATED
