// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/category_repository.dart';
import '../../domain/usecases/category/update_category_usecase.dart';

void registerUpdateCategoryUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateCategoryUseCase>(
    () => UpdateCategoryUseCase(getIt<CategoryRepository>()),
  );
}

// END GENERATED
