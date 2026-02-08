// Auto-generated DI registration for ProductMockDataSource
import 'package:get_it/get_it.dart';
import '../../data/data_sources/product/product_mock_data_source.dart';

void registerProductMockDataSource(GetIt getIt) {
  getIt.registerLazySingleton<ProductMockDataSource>(
    () => ProductMockDataSource(),
  );
}
