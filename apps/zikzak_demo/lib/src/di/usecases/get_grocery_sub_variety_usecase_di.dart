// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_sub_variety_repository.dart';
import '../../domain/usecases/grocery_sub_variety/get_grocery_sub_variety_usecase.dart';

void registerGetGrocerySubVarietyUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetGrocerySubVarietyUseCase>(
    () => GetGrocerySubVarietyUseCase(getIt<GrocerySubVarietyRepository>()),
  );
}

// END GENERATED
