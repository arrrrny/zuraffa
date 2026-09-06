// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/form_option_repository.dart';
import '../../domain/usecases/form_option/update_form_option_usecase.dart';

void registerUpdateFormOptionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateFormOptionUseCase>(
    () => UpdateFormOptionUseCase(getIt<FormOptionRepository>()),
  );
}

// END GENERATED
