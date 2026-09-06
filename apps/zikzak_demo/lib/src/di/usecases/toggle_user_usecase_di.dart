// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/user/toggle_user_usecase.dart';

void registerToggleUserUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleUserUseCase>(
    () => ToggleUserUseCase(getIt<UserRepository>()),
  );
}

// END GENERATED
