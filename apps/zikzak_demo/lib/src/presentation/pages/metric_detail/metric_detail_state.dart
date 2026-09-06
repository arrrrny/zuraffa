// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/metric_detail/metric_detail.dart';

class MetricDetailState {
  const MetricDetailState({
    this.error,
    this.metricDetail,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single MetricDetail entity
  final MetricDetail? metricDetail;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  MetricDetailState copyWith({
    AppFailure? error,
    MetricDetail? metricDetail,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => MetricDetailState(
    error: error ?? this.error,
    metricDetail: metricDetail ?? this.metricDetail,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetricDetailState &&
          other.error == error &&
          other.metricDetail == metricDetail &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      metricDetail.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'MetricDetailState(error: $error, metricDetail: $metricDetail)';
}

// END GENERATED
