// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/dynamic_form_field_repository.dart';
import '../../domain/usecases/dynamic_form_field/update_dynamic_form_field_usecase.dart';

void registerUpdateDynamicFormFieldUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateDynamicFormFieldUseCase>(
    () => UpdateDynamicFormFieldUseCase(getIt<DynamicFormFieldRepository>()),
  );
}

// END GENERATED
