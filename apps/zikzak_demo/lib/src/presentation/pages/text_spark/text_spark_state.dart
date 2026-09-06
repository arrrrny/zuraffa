// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/text_spark/text_spark.dart';

class TextSparkState {
  const TextSparkState({
    this.error,
    this.textSpark,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single TextSpark entity
  final TextSpark? textSpark;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  TextSparkState copyWith({
    AppFailure? error,
    TextSpark? textSpark,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => TextSparkState(
    error: error ?? this.error,
    textSpark: textSpark ?? this.textSpark,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextSparkState &&
          other.error == error &&
          other.textSpark == textSpark &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      textSpark.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() => 'TextSparkState(error: $error, textSpark: $textSpark)';
}

// END GENERATED
