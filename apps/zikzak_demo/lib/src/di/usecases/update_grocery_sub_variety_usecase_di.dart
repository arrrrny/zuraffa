// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_sub_variety_repository.dart';
import '../../domain/usecases/grocery_sub_variety/update_grocery_sub_variety_usecase.dart';

void registerUpdateGrocerySubVarietyUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateGrocerySubVarietyUseCase>(
    () => UpdateGrocerySubVarietyUseCase(getIt<GrocerySubVarietyRepository>()),
  );
}

// END GENERATED
