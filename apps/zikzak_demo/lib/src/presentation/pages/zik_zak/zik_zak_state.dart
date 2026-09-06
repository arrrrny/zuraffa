// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/zik_zak/zik_zak.dart';

class ZikZakState {
  const ZikZakState({
    this.error,
    this.zikZak,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single ZikZak entity
  final ZikZak? zikZak;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  ZikZakState copyWith({
    AppFailure? error,
    ZikZak? zikZak,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => ZikZakState(
    error: error ?? this.error,
    zikZak: zikZak ?? this.zikZak,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZikZakState &&
          other.error == error &&
          other.zikZak == zikZak &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      zikZak.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() => 'ZikZakState(error: $error, zikZak: $zikZak)';
}

// END GENERATED
