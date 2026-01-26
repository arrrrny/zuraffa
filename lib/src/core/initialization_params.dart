import 'package:meta/meta.dart';

/// Parameters for initializing a repository or data source.
@immutable
class InitializationParams {
  /// How long to wait for the app to initialize before timing out.
  final Duration timeout;

  /// Whether to bypass cached state and force a fresh initialization.
  final bool forceRefresh;

  /// Optional metadata or environment configuration to pass during startup.
  final Map<String, dynamic>? environmentData;

  /// Create an [InitializationParams] instance.
  const InitializationParams({
    this.timeout = const Duration(seconds: 5),
    this.forceRefresh = false,
    this.environmentData,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InitializationParams &&
          runtimeType == other.runtimeType &&
          timeout == other.timeout &&
          forceRefresh == other.forceRefresh &&
          environmentData == other.environmentData;

  @override
  int get hashCode =>
      timeout.hashCode ^ forceRefresh.hashCode ^ environmentData.hashCode;

  @override
  String toString() =>
      'InitializationParams(timeout: $timeout, forceRefresh: $forceRefresh, environmentData: $environmentData)';
}
