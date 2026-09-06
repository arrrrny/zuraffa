// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_store_repository.dart';
import '../../domain/usecases/grocery_store/get_grocery_store_usecase.dart';

void registerGetGroceryStoreUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetGroceryStoreUseCase>(
    () => GetGroceryStoreUseCase(getIt<GroceryStoreRepository>()),
  );
}

// END GENERATED
