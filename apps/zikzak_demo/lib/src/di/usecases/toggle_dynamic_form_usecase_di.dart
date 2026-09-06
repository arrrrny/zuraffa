// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/dynamic_form_repository.dart';
import '../../domain/usecases/dynamic_form/toggle_dynamic_form_usecase.dart';

void registerToggleDynamicFormUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleDynamicFormUseCase>(
    () => ToggleDynamicFormUseCase(getIt<DynamicFormRepository>()),
  );
}

// END GENERATED
