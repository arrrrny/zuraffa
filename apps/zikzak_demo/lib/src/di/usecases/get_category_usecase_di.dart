// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/category_repository.dart';
import '../../domain/usecases/category/get_category_usecase.dart';

void registerGetCategoryUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetCategoryUseCase>(
    () => GetCategoryUseCase(getIt<CategoryRepository>()),
  );
}

// END GENERATED
