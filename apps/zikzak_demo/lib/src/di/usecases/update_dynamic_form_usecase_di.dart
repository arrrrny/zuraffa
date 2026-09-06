// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/dynamic_form_repository.dart';
import '../../domain/usecases/dynamic_form/update_dynamic_form_usecase.dart';

void registerUpdateDynamicFormUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateDynamicFormUseCase>(
    () => UpdateDynamicFormUseCase(getIt<DynamicFormRepository>()),
  );
}

// END GENERATED
