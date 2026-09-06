// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/subscription/subscription.dart';

class SubscriptionState {
  const SubscriptionState({
    this.error,
    this.subscription,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single Subscription entity
  final Subscription? subscription;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  SubscriptionState copyWith({
    AppFailure? error,
    Subscription? subscription,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => SubscriptionState(
    error: error ?? this.error,
    subscription: subscription ?? this.subscription,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionState &&
          other.error == error &&
          other.subscription == subscription &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      subscription.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'SubscriptionState(error: $error, subscription: $subscription)';
}

// END GENERATED
