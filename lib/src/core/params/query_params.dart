import 'package:zorphy_annotation/zorphy_annotation.dart';

import '../failure.dart';
import 'converters/filter_converter.dart';
import 'list_query_params.dart';
import 'params.dart';

part 'query_params.zorphy.dart';

/// Parameters for querying a single entity by a field (usually ID or slug).
///
/// The type parameter [T] represents the entity type being queried,
/// enabling type-safe [ZorphyFilter] predicates built from the entity's
/// `<T>Fields` registry.
@ZorphyValue()
@Deprecated(
  'Replaced in v8 by ZfaQuery<T> and concrete @ZorphyIntent classes in ZFA-008/ZFA-017',
)
abstract class $QueryParams<T> implements Params {
  const $QueryParams();

  /// Type-safe predicate to identify the entity.
  ZorphyFilter<T>? get filter;

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
  /// params — the id lookup generated mock datasources rely on. Throws an
  /// [AppFailure.notFound] when nothing matches, when a params-only query cannot
  /// be verified against an entity that exposes no JSON view, and on an empty
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
      _throwNotFound('matches the query filter ${filter.toWire()}');
    }
    if (criteria == null || criteria.isEmpty) {
      _throwNotFound('is available for an unfiltered query');
    }
    _throwNotFound('matches the query params $criteria');
  }

  /// Throws the not-found failure for a query that matched nothing, naming
  /// what was searched so a miss is easy to triage from the log line alone.
  Never _throwNotFound(String reason) =>
      throw AppFailure.notFound(message: 'No $T $reason');
}

/// The JSON view of [item] when it exposes one, or null when it cannot be
/// compared by field.
///
/// Zorphy v3 entities expose `toWire()` as an instance method; `toJson()` is
/// only reachable for hand-written types that declare it (hence the
/// fallback), and v2's `toJsonLean()` is honoured for consumers still on it.
Map<dynamic, dynamic>? _jsonViewOf(Object? item) {
  if (item is Map) return item;
  final dynamic value = item;
  try {
    final view = value.toWire();
    return view is Map ? view : null;
  } on NoSuchMethodError {
    try {
      final view = value.toJson();
      return view is Map ? view : null;
    } on NoSuchMethodError {
      try {
        final view = value.toJsonLean();
        return view is Map ? view : null;
      } on NoSuchMethodError {
        return null;
      }
    }
  }
}

/// Extension methods for converting a [ZorphyFilter] to [QueryParams].
extension FilterToQueryExtension<T> on ZorphyFilter<T> {
  /// Converts this filter to a [QueryParams] object.
  QueryParams<T> toQuery({Map<String, dynamic>? params}) {
    return QueryParams<T>.fromTrusted(filter: this, params: params);
  }
}

/// Extension methods for converting a list of [ZorphyFilter]s to a single
/// filter or [QueryParams].
extension FilterListToQueryExtension<T> on Iterable<ZorphyFilter<T>> {
  /// Combines multiple filters into a single conjunction.
  ///
  /// No filters is the neutral element — a conjunction of nothing matches
  /// everything (`ZorphyAnd([])` is vacuously true).
  ZorphyFilter<T> toFilter() {
    final filters = toList();
    if (filters.length == 1) return filters.single;
    return ZorphyAnd<T>(filters);
  }

  /// Combines multiple filters into a [QueryParams] object.
  QueryParams<T> toQuery({Map<String, dynamic>? params}) {
    return QueryParams<T>.fromTrusted(filter: toFilter(), params: params);
  }
}

/// The neutral predicate — matches every instance. The v3 analogue of v2's
/// `AlwaysMatch<T>()`: an empty conjunction (`ZorphyAnd([])` is vacuously
/// true).
ZorphyFilter<T> alwaysMatch<T>() => ZorphyAnd<T>(const []);

/// Nested filtering over a value field: the field descriptor projects a
/// predicate over the nested type onto the owning entity
/// (`ZorphyField.nested`, zorphy#303). `ZorphyFilter` is sealed, so this is
/// composition through v3's own combinator — never a zuraffa-defined
/// predicate class.
extension NestedFilterToQueryExtension<TEntity, TValue>
    on ZorphyField<TEntity, TValue> {
  /// Filters [TEntity]s by a [QueryParams] over the nested [TValue].
  ZorphyFilter<TEntity> query(QueryParams<TValue> query) =>
      _nestedOrAlways(this, query.filter);

  /// Filters [TEntity]s by a [ListQueryParams] over the nested [TValue].
  ZorphyFilter<TEntity> list(ListQueryParams<TValue> query) =>
      _nestedOrAlways(this, query.filter);
}

/// Nested filtering over an `Iterable<TElement>` field: `ZorphyNested`
/// matches the entity when ANY element matches the nested predicate.
extension NestedIterableFilterToQueryExtension<TEntity, TElement>
    on ZorphyField<TEntity, List<TElement>> {
  ZorphyFilter<TEntity> query(QueryParams<TElement> query) =>
      _nestedOrAlways(this, query.filter);

  ZorphyFilter<TEntity> list(ListQueryParams<TElement> query) =>
      _nestedOrAlways(this, query.filter);
}

/// Nested filtering over a nullable `Iterable<TElement>` field.
extension NestedNullableIterableFilterToQueryExtension<TEntity, TElement>
    on ZorphyField<TEntity, List<TElement>?> {
  ZorphyFilter<TEntity> query(QueryParams<TElement> query) =>
      _nestedOrAlways(this, query.filter);

  ZorphyFilter<TEntity> list(ListQueryParams<TElement> query) =>
      _nestedOrAlways(this, query.filter);
}

ZorphyFilter<TEntity> _nestedOrAlways<TEntity, TValue>(
  ZorphyField<TEntity, TValue> field,
  ZorphyFilter<TValue>? inner,
) {
  if (inner == null) return alwaysMatch<TEntity>();
  return field.nested(inner);
}

/// Serialize a [QueryParams] to a wire map.
///
/// Hand-written for the same reason as [queryParamsFromWire]: the generated
/// `toWire` stores the `ZorphyFilter<T>` as an object, but a wire map must
/// carry its JSON form ([FilterConverter.toJson]).
Map<String, dynamic> queryParamsToWire<T>(QueryParams<T> params) => {
  'params': params.params,
  if (params.filter != null) 'filter': FilterConverter.toJson(params.filter!),
};

/// Decode a [QueryParams] from a wire map.
///
/// Hand-written for the same reason as [listQueryParamsFromWire]: the
/// generated `fromWire` boundary-casts `raw['filter']` to a `ZorphyFilter<T>`,
/// but a wire filter is a JSON map that must be BOUND to a typed field of `T`
/// first. [resolveField] maps a field pointer to the entity's erased
/// `ZorphyField<T, Object?>` — `<T>Fields.all.byPointer` is the canonical
/// resolver; without one there is nothing to bind to.
QueryParams<T> queryParamsFromWire<T>(
  Map<String, dynamic> raw,
  T Function(Object? json) fromElement,
  FieldResolver<T> resolveField,
) {
  return QueryParams<T>.fromTrusted(
    params: raw['params'] as Map<String, dynamic>?,
    filter: FilterConverter.fromJsonTyped<T>(
      raw['filter'] as Map<String, dynamic>?,
      resolveField,
    ),
  );
}
