// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/walkthrough/walkthrough.dart';

class WalkthroughState {
  const WalkthroughState({
    this.error,
    this.walkthrough,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single Walkthrough entity
  final Walkthrough? walkthrough;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  WalkthroughState copyWith({
    AppFailure? error,
    Walkthrough? walkthrough,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => WalkthroughState(
    error: error ?? this.error,
    walkthrough: walkthrough ?? this.walkthrough,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalkthroughState &&
          other.error == error &&
          other.walkthrough == walkthrough &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      walkthrough.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'WalkthroughState(error: $error, walkthrough: $walkthrough)';
}

// END GENERATED
