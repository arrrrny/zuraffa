// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/locale_repository.dart';
import '../../domain/usecases/locale/update_locale_usecase.dart';

void registerUpdateLocaleUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateLocaleUseCase>(
    () => UpdateLocaleUseCase(getIt<LocaleRepository>()),
  );
}

// END GENERATED
