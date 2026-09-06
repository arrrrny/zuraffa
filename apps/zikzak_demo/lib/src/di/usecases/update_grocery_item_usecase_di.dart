// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_item_repository.dart';
import '../../domain/usecases/grocery_item/update_grocery_item_usecase.dart';

void registerUpdateGroceryItemUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateGroceryItemUseCase>(
    () => UpdateGroceryItemUseCase(getIt<GroceryItemRepository>()),
  );
}

// END GENERATED
