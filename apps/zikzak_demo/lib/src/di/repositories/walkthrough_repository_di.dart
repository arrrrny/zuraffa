// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/walkthrough/walkthrough_remote_datasource.dart';
import '../../data/repositories/data_walkthrough_repository.dart';
import '../../domain/repositories/walkthrough_repository.dart';

void registerWalkthroughRepository(GetIt getIt) {
  getIt.registerLazySingleton<WalkthroughRepository>(
    () => DataWalkthroughRepository(getIt<WalkthroughRemoteDataSource>()),
  );
}

// END GENERATED
