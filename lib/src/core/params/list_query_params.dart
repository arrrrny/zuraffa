import 'package:zorphy_annotation/zorphy_annotation.dart';
import 'package:zuraffa/src/core/params/index.dart';

part 'list_query_params.zorphy.dart';

/// Parameters for querying a list of entities.
///
/// Use [ListQueryParams] to pass common query options like typed filtering,
/// sorting, and pagination to list-based UseCases.
///
/// The type parameter [T] represents the entity type being queried,
/// enabling type-safe [ZorphyFilter], [ZorphyField], and [ZorphySort]
/// references through the entity's `<T>Fields` registry.
@ZorphyValue()
@Deprecated(
  'Replaced in v8 by ZfaQuery<T> and concrete @ZorphyIntent classes in ZFA-008/ZFA-017',
)
abstract class $ListQueryParams<T> implements Params {
  const $ListQueryParams();

  /// A search string for filtering results.
  String? get search;

  /// A type-safe predicate to apply to the query.
  ZorphyFilter<T>? get filter;

  /// A type-safe sort specification.
  ZorphySort<T>? get sort;

  /// Maximum number of items to return.
  int? get limit;

  /// Number of items to skip.
  int? get offset;

  /// Optional additional parameters (inherited from the params base in v2;
  /// declared explicitly under v3, whose codegen does not merge base fields).
  @override
  Map<String, dynamic>? get params;
}

/// Extension methods for converting a [ZorphyFilter] to [ListQueryParams].
extension FilterToListQueryExtension<T> on ZorphyFilter<T> {
  /// Converts this filter to a [ListQueryParams] object.
  ListQueryParams<T> toListQuery({
    String? search,
    ZorphySort<T>? sort,
    int? limit,
    int? offset,
    Map<String, dynamic>? params,
  }) {
    return ListQueryParams<T>.fromTrusted(
      filter: this,
      search: search,
      sort: sort,
      limit: limit,
      offset: offset,
      params: params,
    );
  }
}

/// Extension methods for converting a list of [ZorphyFilter]s to a single
/// filter or [ListQueryParams].
extension FilterListToListQueryExtension<T> on Iterable<ZorphyFilter<T>> {
  /// Combines multiple filters into a [ListQueryParams] object using a
  /// conjunction.
  ListQueryParams<T> toListQuery({
    String? search,
    ZorphySort<T>? sort,
    int? limit,
    int? offset,
    Map<String, dynamic>? params,
  }) {
    return ListQueryParams<T>.fromTrusted(
      filter: ZorphyAnd<T>(toList()),
      search: search,
      sort: sort,
      limit: limit,
      offset: offset,
      params: params,
    );
  }
}

extension ListQueryParamsExtension on ListQueryParams {
  /// Generates a stable cache key based on query parameters.
  /// This replaces the unstable .hashCode which changes across app restarts.
  String toCacheKey() {
    final parts = <String>[];

    // Add basic fields if they exist (based on typical ListQueryParams structure)
    // We use a safe approach by converting to string if we're not sure about the exact fields
    // but typically ListQueryParams has limit, offset, filter, sort, search.

    try {
      parts.add('l:${limit ?? 'n'}_');
      parts.add('o:${offset ?? 'n'}_');

      if (search != null && search!.isNotEmpty) {
        parts.add('s:${search}_');
      }

      if (filter != null) {
        parts.add('f:${filter.hashCode}_');
      }

      if (sort != null) {
        parts.add('st:${sort.hashCode}_');
      }
    } catch (e) {
      // Fallback to a simple string if fields are missing or different
      parts.add(toString());
    }

    return parts.join();
  }
}

/// Serialize a [ListQueryParams] to a wire map.
///
/// Hand-written for the same reason as [listQueryParamsFromWire]: the
/// generated `toWire` stores `ZorphyFilter<T>`/`ZorphySort<T>` as objects,
/// but a wire map must carry their JSON form ([FilterConverter.toJson],
/// [SortConverter.toJson]).
Map<String, dynamic> listQueryParamsToWire<T>(ListQueryParams<T> params) => {
  'search': params.search,
  'limit': params.limit,
  'offset': params.offset,
  'params': params.params,
  if (params.filter != null) 'filter': FilterConverter.toJson(params.filter!),
  if (params.sort != null) 'sort': SortConverter.toJson(params.sort!),
};

/// Decode a [ListQueryParams] from a wire map.
///
/// This is deliberately hand-written rather than the generated `fromWire`:
/// the generated codec boundary-casts `raw['filter']` to a `ZorphyFilter<T>`,
/// but a wire filter is a JSON map that must be BOUND to a typed field of `T`
/// first. [resolveField] maps a field pointer to the entity's erased
/// `ZorphyField<T, Object?>` — `<T>Fields.all.byPointer` is the canonical
/// resolver; an unknown pointer or op throws [FormatException] rather than
/// decoding into a predicate that cannot read the entity.
ListQueryParams<T> listQueryParamsFromWire<T>(
  Map<String, dynamic> raw,
  T Function(Object? json) fromElement,
  FieldResolver<T> resolveField,
) {
  return ListQueryParams<T>.fromTrusted(
    search: raw['search'] as String?,
    limit: raw['limit'] as int?,
    offset: raw['offset'] as int?,
    params: raw['params'] as Map<String, dynamic>?,
    filter: FilterConverter.fromJsonTyped<T>(
      raw['filter'] as Map<String, dynamic>?,
      resolveField,
    ),
    sort: SortConverter.fromJsonTyped<T>(
      raw['sort'] as Map<String, dynamic>?,
      resolveField,
    ),
  );
}
