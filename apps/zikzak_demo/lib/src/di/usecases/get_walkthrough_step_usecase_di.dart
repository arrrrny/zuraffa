// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/walkthrough_step_repository.dart';
import '../../domain/usecases/walkthrough_step/get_walkthrough_step_usecase.dart';

void registerGetWalkthroughStepUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetWalkthroughStepUseCase>(
    () => GetWalkthroughStepUseCase(getIt<WalkthroughStepRepository>()),
  );
}

// END GENERATED
