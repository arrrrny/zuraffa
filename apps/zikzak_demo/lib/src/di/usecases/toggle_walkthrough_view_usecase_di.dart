// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/walkthrough_view_repository.dart';
import '../../domain/usecases/walkthrough_view/toggle_walkthrough_view_usecase.dart';

void registerToggleWalkthroughViewUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleWalkthroughViewUseCase>(
    () => ToggleWalkthroughViewUseCase(getIt<WalkthroughViewRepository>()),
  );
}

// END GENERATED
