// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/category_repository.dart';
import '../../domain/usecases/category/toggle_category_usecase.dart';

void registerToggleCategoryUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleCategoryUseCase>(
    () => ToggleCategoryUseCase(getIt<CategoryRepository>()),
  );
}

// END GENERATED
