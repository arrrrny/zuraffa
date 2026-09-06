// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_product_repository.dart';
import '../../domain/usecases/grocery_product/toggle_grocery_product_usecase.dart';

void registerToggleGroceryProductUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleGroceryProductUseCase>(
    () => ToggleGroceryProductUseCase(getIt<GroceryProductRepository>()),
  );
}

// END GENERATED
