// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/feedback/feedback.dart';

class FeedbackState {
  const FeedbackState({
    this.error,
    this.feedback,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single Feedback entity
  final Feedback? feedback;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  FeedbackState copyWith({
    AppFailure? error,
    Feedback? feedback,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => FeedbackState(
    error: error ?? this.error,
    feedback: feedback ?? this.feedback,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackState &&
          other.error == error &&
          other.feedback == feedback &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      feedback.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() => 'FeedbackState(error: $error, feedback: $feedback)';
}

// END GENERATED
