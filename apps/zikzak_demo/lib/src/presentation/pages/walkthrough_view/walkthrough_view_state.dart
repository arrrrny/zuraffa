// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/walkthrough_view/walkthrough_view.dart';

class WalkthroughViewState {
  const WalkthroughViewState({
    this.error,
    this.walkthroughView,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single WalkthroughView entity
  final WalkthroughView? walkthroughView;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  WalkthroughViewState copyWith({
    AppFailure? error,
    WalkthroughView? walkthroughView,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => WalkthroughViewState(
    error: error ?? this.error,
    walkthroughView: walkthroughView ?? this.walkthroughView,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalkthroughViewState &&
          other.error == error &&
          other.walkthroughView == walkthroughView &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      walkthroughView.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'WalkthroughViewState(error: $error, walkthroughView: $walkthroughView)';
}

// END GENERATED
