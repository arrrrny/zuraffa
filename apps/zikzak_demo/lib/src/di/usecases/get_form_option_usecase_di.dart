// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/form_option_repository.dart';
import '../../domain/usecases/form_option/get_form_option_usecase.dart';

void registerGetFormOptionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetFormOptionUseCase>(
    () => GetFormOptionUseCase(getIt<FormOptionRepository>()),
  );
}

// END GENERATED
