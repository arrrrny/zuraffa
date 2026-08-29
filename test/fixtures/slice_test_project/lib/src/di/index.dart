/// DI barrel (fixture for spec 043): re-exports every registration so
/// bootstrap imports a single file. Barrel resolution must only pull the
/// registrations a slice actually needs (FR-005).
library;

export 'repositories/product_repository_di.dart';
export 'usecases/fetch_settings_usecase_di.dart';
export 'usecases/get_product_usecase_di.dart';
export 'usecases/update_product_usecase_di.dart';

import 'package:get_it/get_it.dart';

import 'repositories/product_repository_di.dart';
import 'usecases/fetch_settings_usecase_di.dart';
import 'usecases/get_product_usecase_di.dart';
import 'usecases/update_product_usecase_di.dart';

/// Registers every dependency the app needs.
void setupDependencies() {
  final getIt = GetIt.instance;
  registerProductRepository(getIt);
  registerFetchSettingsUseCase(getIt);
  registerGetProductUseCase(getIt);
  registerUpdateProductUseCase(getIt);
}
