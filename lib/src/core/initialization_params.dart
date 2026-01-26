import 'dart:ui';

import 'package:meta/meta.dart';
import 'params.dart';

/// Parameters for initializing a repository or data source.
@immutable
class InitializationParams {
  /// How long to wait for the app to initialize before timing out.
  final Duration timeout;

  /// Whether to bypass cached state and force a fresh initialization.
  final bool forceRefresh;

  /// Optional parameters to pass during startup.
  final Params? params;

  /// Credentials for authentication during initialization.
  final Params? credentials;

  /// Custom settings for the initialization process.
  final Params? settings;

  /// The locale to use for initialization.
  final Locale? locale;

  /// Create an [InitializationParams] instance.
  const InitializationParams({
    this.timeout = const Duration(seconds: 5),
    this.forceRefresh = false,
    this.params,
    this.credentials,
    this.settings,
    this.locale,
  });

  /// Create a copy of [InitializationParams] with optional new values.
  InitializationParams copyWith({
    Duration? timeout,
    bool? forceRefresh,
    Params? params,
    Params? credentials,
    Params? settings,
    Locale? locale,
  }) {
    return InitializationParams(
      timeout: timeout ?? this.timeout,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      params: params ?? this.params,
      credentials: credentials ?? this.credentials,
      settings: settings ?? this.settings,
      locale: locale ?? this.locale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InitializationParams &&
          runtimeType == other.runtimeType &&
          timeout == other.timeout &&
          forceRefresh == other.forceRefresh &&
          params == other.params &&
          credentials == other.credentials &&
          settings == other.settings &&
          locale == other.locale;

  @override
  int get hashCode =>
      timeout.hashCode ^
      forceRefresh.hashCode ^
      params.hashCode ^
      credentials.hashCode ^
      settings.hashCode ^
      locale.hashCode;

  @override
  String toString() =>
      'InitializationParams(timeout: $timeout, forceRefresh: $forceRefresh, params: $params, credentials: $credentials, settings: $settings, locale: $locale)';
}
