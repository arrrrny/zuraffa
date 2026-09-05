// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/foo_repository.dart';
import '../../domain/usecases/foo/update_foo_usecase.dart';

void registerUpdateFooUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateFooUseCase>(
    () => UpdateFooUseCase(getIt<FooRepository>()),
  );
}

// END GENERATED
