// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/dynamic_form_repository.dart';
import '../../domain/usecases/dynamic_form/get_dynamic_form_usecase.dart';

void registerGetDynamicFormUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetDynamicFormUseCase>(
    () => GetDynamicFormUseCase(getIt<DynamicFormRepository>()),
  );
}

// END GENERATED
