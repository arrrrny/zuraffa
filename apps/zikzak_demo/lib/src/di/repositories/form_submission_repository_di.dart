// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/form_submission/form_submission_remote_datasource.dart';
import '../../data/repositories/data_form_submission_repository.dart';
import '../../domain/repositories/form_submission_repository.dart';

void registerFormSubmissionRepository(GetIt getIt) {
  getIt.registerLazySingleton<FormSubmissionRepository>(
    () => DataFormSubmissionRepository(getIt<FormSubmissionRemoteDataSource>()),
  );
}

// END GENERATED
