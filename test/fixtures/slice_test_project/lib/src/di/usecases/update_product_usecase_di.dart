/// DI registration for UpdateProductUseCase (fixture for spec 043).
library;

import 'package:get_it/get_it.dart';

import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/product/update_product_usecase.dart';

/// Registers [UpdateProductUseCase].
void registerUpdateProductUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateProductUseCase>(
    () => UpdateProductUseCase(getIt<ProductRepository>()),
  );
}
