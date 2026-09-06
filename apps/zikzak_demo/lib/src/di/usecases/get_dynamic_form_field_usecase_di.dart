// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/dynamic_form_field_repository.dart';
import '../../domain/usecases/dynamic_form_field/get_dynamic_form_field_usecase.dart';

void registerGetDynamicFormFieldUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetDynamicFormFieldUseCase>(
    () => GetDynamicFormFieldUseCase(getIt<DynamicFormFieldRepository>()),
  );
}

// END GENERATED
