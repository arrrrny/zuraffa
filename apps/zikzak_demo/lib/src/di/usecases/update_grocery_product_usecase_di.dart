// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_product_repository.dart';
import '../../domain/usecases/grocery_product/update_grocery_product_usecase.dart';

void registerUpdateGroceryProductUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateGroceryProductUseCase>(
    () => UpdateGroceryProductUseCase(getIt<GroceryProductRepository>()),
  );
}

// END GENERATED
