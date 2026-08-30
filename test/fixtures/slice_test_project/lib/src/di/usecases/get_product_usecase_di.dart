/// DI registration for GetProductUseCase (fixture for spec 043).
library;

import 'package:get_it/get_it.dart';

import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/product/get_product_usecase.dart';

/// Registers [GetProductUseCase] and its dependencies.
void registerGetProductUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetProductUseCase>(
    () => GetProductUseCase(getIt<ProductRepository>()),
  );
}
