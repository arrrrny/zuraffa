// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/walkthrough_repository.dart';
import '../../domain/usecases/walkthrough/get_walkthrough_usecase.dart';

void registerGetWalkthroughUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetWalkthroughUseCase>(
    () => GetWalkthroughUseCase(getIt<WalkthroughRepository>()),
  );
}

// END GENERATED
