import 'package:zorphy/zorphy.dart';

import '../failure.dart';
import 'converters/filter_converter.dart';
import 'list_query_params.dart';
import 'params.dart';

part 'query_params.zorphy.dart';

part 'query_params.g.dart';

/// Parameters for querying a single entity by a field (usually ID or slug).
///
/// The type parameter [T] represents the entity type being queried,
/// enabling type-safe [Filter] references when the entity has filterable fields.
@Zorphy(generateJson: true, generateFilter: true)
abstract class $QueryParams<T> implements $$Params {
  const $QueryParams();

  /// Type-safe filter to identify the entity.
  @JsonKey(
    toJson: FilterConverter.toJson,
    fromJson: FilterConverter.fromJson,
    includeFromJson: false,
    includeToJson: false,
  )
  Filter<T>? get filter;
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
      throw NotFoundFailure(
        'No $T matches the query filter',
        resourceType: '$T',
      );
    }
    if (criteria == null || criteria.isEmpty) {
      throw NotFoundFailure(
        'No $T is available for an unfiltered query',
        resourceType: '$T',
      );
    }
    throw NotFoundFailure('No $T matches the query params', resourceType: '$T');
  }
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
      return null;
    }
  }
}

/// Extension methods for converting [Filter] to [QueryParams].
extension FilterToQueryExtension<T> on Filter<T> {
  /// Converts this filter to a [QueryParams] object.
  QueryParams<T> toQuery({Map<String, dynamic>? params}) {
    return QueryParams<T>(filter: this, params: params);
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
    return QueryParams<T>(filter: toFilter(), params: params);
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
