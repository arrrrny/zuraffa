// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/walkthrough_step_repository.dart';
import '../../domain/usecases/walkthrough_step/update_walkthrough_step_usecase.dart';

void registerUpdateWalkthroughStepUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateWalkthroughStepUseCase>(
    () => UpdateWalkthroughStepUseCase(getIt<WalkthroughStepRepository>()),
  );
}

// END GENERATED
