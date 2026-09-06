// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/form_submission/form_submission.dart';

class FormSubmissionState {
  const FormSubmissionState({
    this.error,
    this.formSubmission,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single FormSubmission entity
  final FormSubmission? formSubmission;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  FormSubmissionState copyWith({
    AppFailure? error,
    FormSubmission? formSubmission,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => FormSubmissionState(
    error: error ?? this.error,
    formSubmission: formSubmission ?? this.formSubmission,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormSubmissionState &&
          other.error == error &&
          other.formSubmission == formSubmission &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      formSubmission.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'FormSubmissionState(error: $error, formSubmission: $formSubmission)';
}

// END GENERATED
