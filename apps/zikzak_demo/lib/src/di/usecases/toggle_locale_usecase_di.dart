// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/locale_repository.dart';
import '../../domain/usecases/locale/toggle_locale_usecase.dart';

void registerToggleLocaleUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleLocaleUseCase>(
    () => ToggleLocaleUseCase(getIt<LocaleRepository>()),
  );
}

// END GENERATED
