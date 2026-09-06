// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/form_submission_repository.dart';
import '../../domain/usecases/form_submission/toggle_form_submission_usecase.dart';

void registerToggleFormSubmissionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleFormSubmissionUseCase>(
    () => ToggleFormSubmissionUseCase(getIt<FormSubmissionRepository>()),
  );
}

// END GENERATED
