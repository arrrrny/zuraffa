// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/text_listing/text_listing_remote_datasource.dart';
import '../../data/repositories/data_text_listing_repository.dart';
import '../../domain/repositories/text_listing_repository.dart';

void registerTextListingRepository(GetIt getIt) {
  getIt.registerLazySingleton<TextListingRepository>(
    () => DataTextListingRepository(getIt<TextListingRemoteDataSource>()),
  );
}

// END GENERATED
