// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/listing/listing_remote_datasource.dart';
import '../../data/repositories/data_listing_repository.dart';
import '../../domain/repositories/listing_repository.dart';

void registerListingRepository(GetIt getIt) {
  getIt.registerLazySingleton<ListingRepository>(
    () => DataListingRepository(getIt<ListingRemoteDataSource>()),
  );
}

// END GENERATED
