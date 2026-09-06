// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/url_spark/url_spark.dart';

class UrlSparkState {
  const UrlSparkState({
    this.error,
    this.urlSpark,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single UrlSpark entity
  final UrlSpark? urlSpark;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  UrlSparkState copyWith({
    AppFailure? error,
    UrlSpark? urlSpark,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => UrlSparkState(
    error: error ?? this.error,
    urlSpark: urlSpark ?? this.urlSpark,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlSparkState &&
          other.error == error &&
          other.urlSpark == urlSpark &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      urlSpark.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() => 'UrlSparkState(error: $error, urlSpark: $urlSpark)';
}

// END GENERATED
