// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/form_option/form_option.dart';

class FormOptionState {
  const FormOptionState({
    this.error,
    this.formOption,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single FormOption entity
  final FormOption? formOption;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  FormOptionState copyWith({
    AppFailure? error,
    FormOption? formOption,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => FormOptionState(
    error: error ?? this.error,
    formOption: formOption ?? this.formOption,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormOptionState &&
          other.error == error &&
          other.formOption == formOption &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      formOption.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'FormOptionState(error: $error, formOption: $formOption)';
}

// END GENERATED
