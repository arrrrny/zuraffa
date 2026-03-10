import 'package:get_it/get_it.dart';

import '../../data/datasources/product/product_mock_datasource.dart';

void registerProductMockDataSource(GetIt getIt) {
  getIt.registerLazySingleton<ProductMockDataSource>(
    () => ProductMockDataSource(),
  );
}
