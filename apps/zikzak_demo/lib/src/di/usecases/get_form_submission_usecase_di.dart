// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/form_submission_repository.dart';
import '../../domain/usecases/form_submission/get_form_submission_usecase.dart';

void registerGetFormSubmissionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetFormSubmissionUseCase>(
    () => GetFormSubmissionUseCase(getIt<FormSubmissionRepository>()),
  );
}

// END GENERATED
