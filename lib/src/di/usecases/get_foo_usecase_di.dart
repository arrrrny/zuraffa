// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/foo_repository.dart';
import '../../domain/usecases/foo/get_foo_usecase.dart';

void registerGetFooUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetFooUseCase>(
    () => GetFooUseCase(getIt<FooRepository>()),
  );
}

// END GENERATED
