// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/user/get_user_usecase.dart';

void registerGetUserUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetUserUseCase>(
    () => GetUserUseCase(getIt<UserRepository>()),
  );
}

// END GENERATED
