// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/walkthrough_view_repository.dart';
import '../../domain/usecases/walkthrough_view/get_walkthrough_view_usecase.dart';

void registerGetWalkthroughViewUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetWalkthroughViewUseCase>(
    () => GetWalkthroughViewUseCase(getIt<WalkthroughViewRepository>()),
  );
}

// END GENERATED
