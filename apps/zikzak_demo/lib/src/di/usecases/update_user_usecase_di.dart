// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/user/update_user_usecase.dart';

void registerUpdateUserUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateUserUseCase>(
    () => UpdateUserUseCase(getIt<UserRepository>()),
  );
}

// END GENERATED
