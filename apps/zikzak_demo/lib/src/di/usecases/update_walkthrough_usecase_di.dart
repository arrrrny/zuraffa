// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/walkthrough_repository.dart';
import '../../domain/usecases/walkthrough/update_walkthrough_usecase.dart';

void registerUpdateWalkthroughUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateWalkthroughUseCase>(
    () => UpdateWalkthroughUseCase(getIt<WalkthroughRepository>()),
  );
}

// END GENERATED
