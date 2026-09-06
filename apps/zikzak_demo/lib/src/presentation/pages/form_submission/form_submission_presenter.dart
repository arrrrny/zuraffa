// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/form_submission/form_submission.dart';
import '../../../domain/usecases/form_submission/get_form_submission_usecase.dart';
import '../../../domain/usecases/form_submission/toggle_form_submission_usecase.dart';
import '../../../domain/usecases/form_submission/update_form_submission_usecase.dart';

class FormSubmissionPresenter extends Presenter {
  FormSubmissionPresenter() {
    _getFormSubmission = registerUseCase(getIt<GetFormSubmissionUseCase>());
    _updateFormSubmission = registerUseCase(
      getIt<UpdateFormSubmissionUseCase>(),
    );
    _toggleFormSubmission = registerUseCase(
      getIt<ToggleFormSubmissionUseCase>(),
    );
  }

  late final GetFormSubmissionUseCase _getFormSubmission;

  late final UpdateFormSubmissionUseCase _updateFormSubmission;

  late final ToggleFormSubmissionUseCase _toggleFormSubmission;

  Future<Result<FormSubmission, AppFailure>> getFormSubmission(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getFormSubmission.call(
      QueryParams<FormSubmission>(filter: Eq(FormSubmissionFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<FormSubmission, AppFailure>> updateFormSubmission(
    String id,
    FormSubmissionPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateFormSubmission.call(
      UpdateParams<String, FormSubmissionPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<FormSubmission, AppFailure>> toggleFormSubmission(
    String id,
    Field<FormSubmission, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleFormSubmission.call(
      ToggleParams<String, Field<FormSubmission, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
