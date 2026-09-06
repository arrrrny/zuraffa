// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_item_repository.dart';
import '../../domain/usecases/grocery_item/get_grocery_item_usecase.dart';

void registerGetGroceryItemUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetGroceryItemUseCase>(
    () => GetGroceryItemUseCase(getIt<GroceryItemRepository>()),
  );
}

// END GENERATED
