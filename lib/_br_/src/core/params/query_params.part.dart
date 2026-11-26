// dart format off
part of '../../../../src/core/params/query_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class QueryParams<T> implements ZorphyValueBase {
  const QueryParams.fromTrusted({this.filter, this.params});

  final Filter<T>? filter;

  final Map<String, dynamic>? params;

  QueryParams<T> copyWith({
    Object? filter = _sentinel,
    Object? params = _sentinel,
  }) {
    return QueryParams<T>.fromTrusted(
      filter: identical(filter, _sentinel) ? this.filter : filter as Filter<T>?,
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QueryParams &&
        this.filter == other.filter &&
        this.params == other.params;
  }

  @override
  int get hashCode => Object.hashAll([filter, params]);

  @override
  String toString() => 'QueryParams(filter: $filter, params: $params)';
}

