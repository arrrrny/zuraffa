// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/form_submission/form_submission.dart';
import 'form_submission_presenter.dart';

class FormSubmissionController extends Controller {
  FormSubmissionController(this._presenter);

  final FormSubmissionPresenter _presenter;

  Future<void> getFormSubmission(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getFormSubmission(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateFormSubmission(
    String id,
    FormSubmissionPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateFormSubmission(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleFormSubmission(
    String id,
    Field<FormSubmission, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleFormSubmission(
      id,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold((toggled) {}, (failure) {});
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
