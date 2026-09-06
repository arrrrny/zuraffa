// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/category/category_remote_datasource.dart';
import '../../data/repositories/data_category_repository.dart';
import '../../domain/repositories/category_repository.dart';

void registerCategoryRepository(GetIt getIt) {
  getIt.registerLazySingleton<CategoryRepository>(
    () => DataCategoryRepository(getIt<CategoryRemoteDataSource>()),
  );
}

// END GENERATED
