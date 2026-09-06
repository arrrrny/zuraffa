// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_store_repository.dart';
import '../../domain/usecases/grocery_store/toggle_grocery_store_usecase.dart';

void registerToggleGroceryStoreUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleGroceryStoreUseCase>(
    () => ToggleGroceryStoreUseCase(getIt<GroceryStoreRepository>()),
  );
}

// END GENERATED
