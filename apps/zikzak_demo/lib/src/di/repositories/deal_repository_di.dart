// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/deal/deal_remote_datasource.dart';
import '../../data/repositories/data_deal_repository.dart';
import '../../domain/repositories/deal_repository.dart';

void registerDealRepository(GetIt getIt) {
  getIt.registerLazySingleton<DealRepository>(
    () => DataDealRepository(getIt<DealRemoteDataSource>()),
  );
}

// END GENERATED
