// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_product_repository.dart';
import '../../domain/usecases/grocery_product/get_grocery_product_usecase.dart';

void registerGetGroceryProductUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetGroceryProductUseCase>(
    () => GetGroceryProductUseCase(getIt<GroceryProductRepository>()),
  );
}

// END GENERATED
