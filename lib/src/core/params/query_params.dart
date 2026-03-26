import 'package:zorphy/zorphy.dart';

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
abstract class $QueryParams<T> implements $Params {
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
  /// Query a single entity matching the filter.
  /// Throws if no entity matches.
  T query(QueryParams<T>? params) {
    if (params?.filter == null) {
      throw ArgumentError(
        'QueryParams must have a non-null filter to query an entity.',
      );
    }
    return where((item) => params!.filter!.matches(item)).first;
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
