// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/dynamic_form_field/dynamic_form_field.dart';

class DynamicFormFieldState {
  const DynamicFormFieldState({
    this.error,
    this.dynamicFormField,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single DynamicFormField entity
  final DynamicFormField? dynamicFormField;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  DynamicFormFieldState copyWith({
    AppFailure? error,
    DynamicFormField? dynamicFormField,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => DynamicFormFieldState(
    error: error ?? this.error,
    dynamicFormField: dynamicFormField ?? this.dynamicFormField,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DynamicFormFieldState &&
          other.error == error &&
          other.dynamicFormField == dynamicFormField &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      dynamicFormField.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'DynamicFormFieldState(error: $error, dynamicFormField: $dynamicFormField)';
}

// END GENERATED
