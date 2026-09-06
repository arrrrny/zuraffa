// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_price_result_repository.dart';
import '../../domain/usecases/grocery_price_result/toggle_grocery_price_result_usecase.dart';

void registerToggleGroceryPriceResultUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleGroceryPriceResultUseCase>(
    () =>
        ToggleGroceryPriceResultUseCase(getIt<GroceryPriceResultRepository>()),
  );
}

// END GENERATED
