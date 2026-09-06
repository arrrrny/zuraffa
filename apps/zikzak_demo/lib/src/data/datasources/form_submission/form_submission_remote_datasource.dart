// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/form_submission/form_submission.dart';
import 'form_submission_datasource.dart';

class FormSubmissionRemoteDataSource
    with Loggable, FailureHandler
    implements FormSubmissionDataSource {
  @override
  Future<FormSubmission> get(QueryParams<FormSubmission> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<FormSubmission> update(
    UpdateParams<String, FormSubmissionPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<FormSubmission> toggle(
    ToggleParams<String, Field<FormSubmission, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
