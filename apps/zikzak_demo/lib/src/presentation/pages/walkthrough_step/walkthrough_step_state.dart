// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/walkthrough_step/walkthrough_step.dart';

class WalkthroughStepState {
  const WalkthroughStepState({
    this.error,
    this.walkthroughStep,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single WalkthroughStep entity
  final WalkthroughStep? walkthroughStep;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  WalkthroughStepState copyWith({
    AppFailure? error,
    WalkthroughStep? walkthroughStep,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => WalkthroughStepState(
    error: error ?? this.error,
    walkthroughStep: walkthroughStep ?? this.walkthroughStep,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalkthroughStepState &&
          other.error == error &&
          other.walkthroughStep == walkthroughStep &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      walkthroughStep.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'WalkthroughStepState(error: $error, walkthroughStep: $walkthroughStep)';
}

// END GENERATED
