import 'package:meta/meta.dart';
import 'params.dart';

/// Parameters for querying a single entity by a field (usually ID or slug).
@immutable
class QueryParams<T> {
  /// The value of the field being queried.
  final T query;

  /// Optional additional parameters for the query.
  final Params? params;

  /// Create a [QueryParams] instance.
  const QueryParams(this.query, [this.params]);

  /// Create a copy of [QueryParams] with optional new values.
  QueryParams<T> copyWith({T? query, Params? params}) {
    return QueryParams<T>(query ?? this.query, params ?? this.params);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryParams<T> &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          params == other.params;

  @override
  int get hashCode => query.hashCode ^ params.hashCode;

  @override
  String toString() => 'QueryParams(query: $query, params: $params)';
}
