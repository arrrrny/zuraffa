// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/walkthrough_step_repository.dart';
import '../../domain/usecases/walkthrough_step/toggle_walkthrough_step_usecase.dart';

void registerToggleWalkthroughStepUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleWalkthroughStepUseCase>(
    () => ToggleWalkthroughStepUseCase(getIt<WalkthroughStepRepository>()),
  );
}

// END GENERATED
