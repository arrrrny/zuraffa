import 'package:meta/meta.dart';
import 'request_params.dart';

/// A class for passing parameters as a map.
///
/// Extends [RequestParams] to provide polymorphic parameter handling.
@immutable
base class Params extends RequestParams {
  /// Optional parameters as a map.
  final Map<String, dynamic>? params;

  /// Create a [Params] instance.
  const Params([this.params]);

  /// Create a copy of [Params] with optional new values.
  Params copyWith({Map<String, dynamic>? params}) {
    return Params(params ?? this.params);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Params &&
          runtimeType == other.runtimeType &&
          params == other.params;

  @override
  int get hashCode => params.hashCode;

  @override
  String toString() => 'Params(params: $params)';
}
