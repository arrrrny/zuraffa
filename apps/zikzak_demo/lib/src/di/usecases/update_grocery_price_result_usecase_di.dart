// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_price_result_repository.dart';
import '../../domain/usecases/grocery_price_result/update_grocery_price_result_usecase.dart';

void registerUpdateGroceryPriceResultUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateGroceryPriceResultUseCase>(
    () =>
        UpdateGroceryPriceResultUseCase(getIt<GroceryPriceResultRepository>()),
  );
}

// END GENERATED
