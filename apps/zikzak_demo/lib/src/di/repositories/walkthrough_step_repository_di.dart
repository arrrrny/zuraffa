// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/walkthrough_step/walkthrough_step_remote_datasource.dart';
import '../../data/repositories/data_walkthrough_step_repository.dart';
import '../../domain/repositories/walkthrough_step_repository.dart';

void registerWalkthroughStepRepository(GetIt getIt) {
  getIt.registerLazySingleton<WalkthroughStepRepository>(
    () =>
        DataWalkthroughStepRepository(getIt<WalkthroughStepRemoteDataSource>()),
  );
}

// END GENERATED
