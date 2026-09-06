// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/form_submission_repository.dart';
import '../../domain/usecases/form_submission/update_form_submission_usecase.dart';

void registerUpdateFormSubmissionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateFormSubmissionUseCase>(
    () => UpdateFormSubmissionUseCase(getIt<FormSubmissionRepository>()),
  );
}

// END GENERATED
