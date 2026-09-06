// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_price_result_repository.dart';
import '../../domain/usecases/grocery_price_result/get_grocery_price_result_usecase.dart';

void registerGetGroceryPriceResultUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetGroceryPriceResultUseCase>(
    () => GetGroceryPriceResultUseCase(getIt<GroceryPriceResultRepository>()),
  );
}

// END GENERATED
