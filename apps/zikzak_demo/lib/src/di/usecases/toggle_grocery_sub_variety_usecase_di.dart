// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_sub_variety_repository.dart';
import '../../domain/usecases/grocery_sub_variety/toggle_grocery_sub_variety_usecase.dart';

void registerToggleGrocerySubVarietyUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleGrocerySubVarietyUseCase>(
    () => ToggleGrocerySubVarietyUseCase(getIt<GrocerySubVarietyRepository>()),
  );
}

// END GENERATED
