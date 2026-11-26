import 'package:zorphy_annotation/zorphy_annotation.dart';

import '../failure.dart';
import 'converters/filter_converter.dart';
import 'converters/sort_converter.dart';
import 'list_query_params.dart';
import 'params.dart';

part '../../../_br_/src/core/params/query_params.part.dart';

/// Parameters for querying a single entity by a field (usually ID or slug).
///
/// The type parameter [T] represents the entity type being queried,
/// enabling type-safe [Filter] references when the entity has filterable fields.
@ZorphyValue()
@Deprecated(
  'Replaced in v8 by ZfaQuery<T> and concrete @ZorphyIntent classes in ZFA-008/ZFA-017',
)
abstract class $QueryParams<T> implements Params {
  const $QueryParams();

  /// Type-safe filter to identify the entity.
  Filter<T>? get filter;

  /// Optional additional parameters (inherited from the params base in v2;
  /// declared explicitly under v3, whose codegen does not merge base fields).
  @override
  Map<String, dynamic>? get params;
}

/// Extension to query a single entity from an iterable using QueryParams.
extension QueryParamsExtension<T> on Iterable<T> {
  /// Query a single entity matching the filter, or matching [QueryParams.params]
  /// when no filter is set.
  ///
  /// A params-only query compares each entity's JSON view against the query's
  /// params — the id lookup generated mock datasources rely on. Throws a
  /// [NotFoundFailure] when nothing matches, when a params-only query cannot be
  /// verified against an entity that exposes no JSON view, and on an empty
  /// iterable — never a raw `StateError`, and never an arbitrary element. With
  /// neither a filter nor params, the first element is returned.
  T query(QueryParams<T>? params) {
    final filter = params?.filter;
    final criteria = params?.params;

    for (final item in this) {
      if (filter != null) {
        if (filter.matches(item)) return item;
        continue;
      }
      if (criteria == null || criteria.isEmpty) return item;
      final view = _jsonViewOf(item);
      if (view != null &&
          criteria.entries.every((entry) => view[entry.key] == entry.value)) {
        return item;
      }
    }

    if (filter != null) {
      _throwNotFound('matches the query filter ${filter.toJson()}');
    }
    if (criteria == null || criteria.isEmpty) {
      _throwNotFound('is available for an unfiltered query');
    }
    _throwNotFound('matches the query params $criteria');
  }

  /// Throws the [NotFoundFailure] for a query that matched nothing, naming what
  /// was searched so a miss is easy to triage from the log line alone.
  Never _throwNotFound(String reason) =>
      throw AppFailure.notFound(message: 'No $T $reason');
}

/// The JSON view of [item] when it exposes one, or null when it cannot be
/// compared by field.
///
/// Zorphy entities generate `toJsonLean()` as an instance method; `toJson()` is
/// generated as an extension for entities (so it is only reachable for
/// hand-written types that declare it as a method), hence the fallback.
Map<dynamic, dynamic>? _jsonViewOf(Object? item) {
  if (item is Map) return item;
  final dynamic value = item;
  try {
    final view = value.toJsonLean();
    return view is Map ? view : null;
  } on NoSuchMethodError {
    try {
      final view = value.toJson();
      return view is Map ? view : null;
    } on NoSuchMethodError {
      try {
        final view = value.toWire();
        return view is Map ? view : null;
      } on NoSuchMethodError {
        return null;
      }
    }
  }
}

/// Extension methods for converting [Filter] to [QueryParams].
extension FilterToQueryExtension<T> on Filter<T> {
  /// Converts this filter to a [QueryParams] object.
  QueryParams<T> toQuery({Map<String, dynamic>? params}) {
    return QueryParams<T>.fromTrusted(filter: this, params: params);
  }
}

/// Extension methods for converting a list of [Filter]s to a single [Filter] or [QueryParams].
extension FilterListToQueryExtension<T> on Iterable<Filter<T>> {
  /// Combines multiple filters into a single [And] filter.
  Filter<T> toFilter() {
    return And<T>(toList());
  }

  /// Combines multiple filters into a [QueryParams] object using an [And] filter.
  QueryParams<T> toQuery({Map<String, dynamic>? params}) {
    return QueryParams<T>.fromTrusted(filter: toFilter(), params: params);
  }
}

/// Extension to support nested filtering with [QueryParams] and [ListQueryParams].
extension NestedFilterToQueryExtension<TEntity, TValue>
    on Field<TEntity, TValue> {
  /// Allows filtering on a nested field using [QueryParams].
  Filter<TEntity> query(QueryParams<TValue> query) {
    if (query.filter == null) return AlwaysMatch<TEntity>();
    return filter(query.filter!);
  }

  /// Allows filtering on a nested field using [ListQueryParams].
  Filter<TEntity> list(ListQueryParams<TValue> query) {
    if (query.filter == null) return AlwaysMatch<TEntity>();
    return filter(query.filter!);
  }
}

/// Extension to support nested filtering for [Iterable] fields.
extension NestedIterableFilterToQueryExtension<TEntity, TElement>
    on Field<TEntity, List<TElement>> {
  /// Allows filtering on a nested [Iterable] field using [QueryParams].
  Filter<TEntity> query(QueryParams<TElement> query) {
    if (query.filter == null) return AlwaysMatch<TEntity>();
    return filter(query.filter!);
  }

  /// Allows filtering on a nested [Iterable] field using [ListQueryParams].
  Filter<TEntity> list(ListQueryParams<TElement> query) {
    if (query.filter == null) return AlwaysMatch<TEntity>();
    return filter(query.filter!);
  }
}

/// Extension to support nested filtering for nullable [Iterable] fields.
extension NestedNullableIterableFilterToQueryExtension<TEntity, TElement>
    on Field<TEntity, List<TElement>?> {
  /// Allows filtering on a nested nullable [Iterable] field using [QueryParams].
  Filter<TEntity> query(QueryParams<TElement> query) {
    if (query.filter == null) return AlwaysMatch<TEntity>();
    return filter(query.filter!);
  }

  /// Allows filtering on a nested nullable [Iterable] field using [ListQueryParams].
  Filter<TEntity> list(ListQueryParams<TElement> query) {
    if (query.filter == null) return AlwaysMatch<TEntity>();
    return filter(query.filter!);
  }
}

/// Serialize a [QueryParams] to a wire map.
///
/// Hand-written for the same reason as [queryParamsFromWire]: the generated
/// `toWire` stores the `Filter<T>` as an object, but a wire map must carry its
/// JSON form ([FilterConverter.toJson]).
Map<String, dynamic> queryParamsToWire<T>(QueryParams<T> params) => {
  'params': params.params,
  if (params.filter != null) 'filter': FilterConverter.toJson(params.filter!),
};

/// Decode a [QueryParams] from a wire map.
///
/// Hand-written for the same reason as [listQueryParamsFromWire]: the
/// generated `fromWire` boundary-casts `raw['filter']` to a `Filter<T>`, but a
/// wire filter is a JSON map that must be BOUND to a typed field of `T` first.
///
/// [fields] / [resolveField] carry typed `Field<T, dynamic>` context so a
/// decoded [Filter] binds to a field of [T]. Without it the converter builds a
/// fallback field whose getter throws for typed entities — the `as Filter<T>?`
/// cast cannot catch that (review #2179).
QueryParams<T> queryParamsFromWire<T>(
  Map<String, dynamic> raw,
  T Function(Object? json) fromElement, [
  Map<String, Field<T, dynamic>>? fields,
  FieldResolver<T>? resolveField,
]) {
  return QueryParams<T>.fromTrusted(
    params: raw['params'] as Map<String, dynamic>?,
    filter: raw['filter'] != null
        ? FilterConverter.fromJsonTyped<T>(
            raw['filter'] as Map<String, dynamic>,
            fields,
            resolveField,
          )
        : null,
  );
}
