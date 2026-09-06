// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/grocery_store_repository.dart';
import '../../domain/usecases/grocery_store/update_grocery_store_usecase.dart';

void registerUpdateGroceryStoreUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateGroceryStoreUseCase>(
    () => UpdateGroceryStoreUseCase(getIt<GroceryStoreRepository>()),
  );
}

// END GENERATED
