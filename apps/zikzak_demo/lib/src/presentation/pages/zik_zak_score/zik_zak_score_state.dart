// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/zik_zak_score/zik_zak_score.dart';

class ZikZakScoreState {
  const ZikZakScoreState({
    this.error,
    this.zikZakScore,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single ZikZakScore entity
  final ZikZakScore? zikZakScore;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  ZikZakScoreState copyWith({
    AppFailure? error,
    ZikZakScore? zikZakScore,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => ZikZakScoreState(
    error: error ?? this.error,
    zikZakScore: zikZakScore ?? this.zikZakScore,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZikZakScoreState &&
          other.error == error &&
          other.zikZakScore == zikZakScore &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      zikZakScore.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'ZikZakScoreState(error: $error, zikZakScore: $zikZakScore)';
}

// END GENERATED
