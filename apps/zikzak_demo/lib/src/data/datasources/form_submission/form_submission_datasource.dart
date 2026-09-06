// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/form_submission/form_submission.dart';

abstract class FormSubmissionDataSource with Loggable, FailureHandler {
  Future<FormSubmission> get(QueryParams<FormSubmission> params);
  Future<FormSubmission> update(
    UpdateParams<String, FormSubmissionPatch> params,
  );
  Future<FormSubmission> toggle(
    ToggleParams<String, Field<FormSubmission, dynamic>> params,
  );
}

// END GENERATED
