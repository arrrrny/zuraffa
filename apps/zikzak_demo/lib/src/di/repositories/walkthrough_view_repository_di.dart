// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/walkthrough_view/walkthrough_view_remote_datasource.dart';
import '../../data/repositories/data_walkthrough_view_repository.dart';
import '../../domain/repositories/walkthrough_view_repository.dart';

void registerWalkthroughViewRepository(GetIt getIt) {
  getIt.registerLazySingleton<WalkthroughViewRepository>(
    () =>
        DataWalkthroughViewRepository(getIt<WalkthroughViewRemoteDataSource>()),
  );
}

// END GENERATED
