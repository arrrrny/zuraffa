// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/form_option_repository.dart';
import '../../domain/usecases/form_option/toggle_form_option_usecase.dart';

void registerToggleFormOptionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleFormOptionUseCase>(
    () => ToggleFormOptionUseCase(getIt<FormOptionRepository>()),
  );
}

// END GENERATED
