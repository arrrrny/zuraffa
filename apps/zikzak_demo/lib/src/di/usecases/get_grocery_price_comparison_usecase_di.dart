// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_price_comparison_repository.dart';
import '../../domain/usecases/grocery_price_comparison/get_grocery_price_comparison_usecase.dart';

void registerGetGroceryPriceComparisonUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetGroceryPriceComparisonUseCase>(
    () => GetGroceryPriceComparisonUseCase(
      getIt<GroceryPriceComparisonRepository>(),
    ),
  );
}

// END GENERATED
