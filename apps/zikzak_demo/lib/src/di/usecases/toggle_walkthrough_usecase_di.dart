// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/walkthrough_repository.dart';
import '../../domain/usecases/walkthrough/toggle_walkthrough_usecase.dart';

void registerToggleWalkthroughUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleWalkthroughUseCase>(
    () => ToggleWalkthroughUseCase(getIt<WalkthroughRepository>()),
  );
}

// END GENERATED
