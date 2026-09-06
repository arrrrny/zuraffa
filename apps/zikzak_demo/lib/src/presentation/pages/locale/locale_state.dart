// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/locale/locale.dart';

class LocaleState {
  const LocaleState({
    this.error,
    this.locale,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single Locale entity
  final Locale? locale;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  LocaleState copyWith({
    AppFailure? error,
    Locale? locale,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => LocaleState(
    error: error ?? this.error,
    locale: locale ?? this.locale,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocaleState &&
          other.error == error &&
          other.locale == locale &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      locale.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() => 'LocaleState(error: $error, locale: $locale)';
}

// END GENERATED
