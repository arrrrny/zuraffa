// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/url_listing/url_listing_remote_datasource.dart';
import '../../data/repositories/data_url_listing_repository.dart';
import '../../domain/repositories/url_listing_repository.dart';

void registerUrlListingRepository(GetIt getIt) {
  getIt.registerLazySingleton<UrlListingRepository>(
    () => DataUrlListingRepository(getIt<UrlListingRemoteDataSource>()),
  );
}

// END GENERATED
