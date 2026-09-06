// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_item_repository.dart';
import '../../domain/usecases/grocery_item/toggle_grocery_item_usecase.dart';

void registerToggleGroceryItemUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleGroceryItemUseCase>(
    () => ToggleGroceryItemUseCase(getIt<GroceryItemRepository>()),
  );
}

// END GENERATED
