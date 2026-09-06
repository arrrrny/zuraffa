// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/dynamic_form/dynamic_form.dart';

class DynamicFormState {
  const DynamicFormState({
    this.error,
    this.dynamicForm,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single DynamicForm entity
  final DynamicForm? dynamicForm;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  DynamicFormState copyWith({
    AppFailure? error,
    DynamicForm? dynamicForm,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => DynamicFormState(
    error: error ?? this.error,
    dynamicForm: dynamicForm ?? this.dynamicForm,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DynamicFormState &&
          other.error == error &&
          other.dynamicForm == dynamicForm &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      dynamicForm.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'DynamicFormState(error: $error, dynamicForm: $dynamicForm)';
}

// END GENERATED
