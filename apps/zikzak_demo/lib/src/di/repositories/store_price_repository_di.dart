// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/store_price/store_price_remote_datasource.dart';
import '../../data/repositories/data_store_price_repository.dart';
import '../../domain/repositories/store_price_repository.dart';

void registerStorePriceRepository(GetIt getIt) {
  getIt.registerLazySingleton<StorePriceRepository>(
    () => DataStorePriceRepository(getIt<StorePriceRemoteDataSource>()),
  );
}

// END GENERATED
