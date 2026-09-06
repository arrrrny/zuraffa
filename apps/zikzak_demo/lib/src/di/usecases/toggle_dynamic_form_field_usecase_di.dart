// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/dynamic_form_field_repository.dart';
import '../../domain/usecases/dynamic_form_field/toggle_dynamic_form_field_usecase.dart';

void registerToggleDynamicFormFieldUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleDynamicFormFieldUseCase>(
    () => ToggleDynamicFormFieldUseCase(getIt<DynamicFormFieldRepository>()),
  );
}

// END GENERATED
