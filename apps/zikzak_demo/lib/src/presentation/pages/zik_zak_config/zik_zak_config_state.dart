// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/zik_zak_config/zik_zak_config.dart';

class ZikZakConfigState {
  const ZikZakConfigState({
    this.error,
    this.zikZakConfig,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single ZikZakConfig entity
  final ZikZakConfig? zikZakConfig;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  ZikZakConfigState copyWith({
    AppFailure? error,
    ZikZakConfig? zikZakConfig,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => ZikZakConfigState(
    error: error ?? this.error,
    zikZakConfig: zikZakConfig ?? this.zikZakConfig,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZikZakConfigState &&
          other.error == error &&
          other.zikZakConfig == zikZakConfig &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      zikZakConfig.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'ZikZakConfigState(error: $error, zikZakConfig: $zikZakConfig)';
}

// END GENERATED
