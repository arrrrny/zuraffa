// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_price_comparison_repository.dart';
import '../../domain/usecases/grocery_price_comparison/toggle_grocery_price_comparison_usecase.dart';

void registerToggleGroceryPriceComparisonUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleGroceryPriceComparisonUseCase>(
    () => ToggleGroceryPriceComparisonUseCase(
      getIt<GroceryPriceComparisonRepository>(),
    ),
  );
}

// END GENERATED
