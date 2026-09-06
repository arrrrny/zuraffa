// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/locale_repository.dart';
import '../../domain/usecases/locale/get_locale_usecase.dart';

void registerGetLocaleUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetLocaleUseCase>(
    () => GetLocaleUseCase(getIt<LocaleRepository>()),
  );
}

// END GENERATED
