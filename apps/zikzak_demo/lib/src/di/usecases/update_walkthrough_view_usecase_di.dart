// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/walkthrough_view_repository.dart';
import '../../domain/usecases/walkthrough_view/update_walkthrough_view_usecase.dart';

void registerUpdateWalkthroughViewUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateWalkthroughViewUseCase>(
    () => UpdateWalkthroughViewUseCase(getIt<WalkthroughViewRepository>()),
  );
}

// END GENERATED
