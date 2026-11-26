import 'package:zorphy_annotation/zorphy_annotation.dart';
import 'package:zuraffa/src/core/params/index.dart';

part '../../../_br_/src/core/params/list_query_params.part.dart';

/// Parameters for querying a list of entities.
///
/// Use [ListQueryParams] to pass common query options like typed filtering,
/// sorting, and pagination to list-based UseCases.
///
/// The type parameter [T] represents the entity type being queried,
/// enabling type-safe [Filter], [Field], and [Sort] references.
@ZorphyValue()
@Deprecated(
  'Replaced in v8 by ZfaQuery<T> and concrete @ZorphyIntent classes in ZFA-008/ZFA-017',
)
abstract class $ListQueryParams<T> implements Params {
  const $ListQueryParams();

  /// A search string for filtering results.
  String? get search;

  /// A type-safe filter to apply to the query.
  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: FilterConverter.toJson,
    fromJson: FilterConverter.fromJson,
  )
  Filter<T>? get filter;

  /// A type-safe sort specification.
  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: SortConverter.toJson,
    fromJson: SortConverter.fromJson,
  )
  Sort<T>? get sort;

  /// Maximum number of items to return.
  int? get limit;

  /// Number of items to skip.
  int? get offset;

  /// Optional additional parameters (inherited from the params base in v2;
  /// declared explicitly under v3, whose codegen does not merge base fields).
  @override
  Map<String, dynamic>? get params;
}

/// Extension methods for converting [Filter] to [ListQueryParams].
extension FilterToListQueryExtension<T> on Filter<T> {
  /// Converts this filter to a [ListQueryParams] object.
  ListQueryParams<T> toListQuery({
    String? search,
    Sort<T>? sort,
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

/// Extension methods for converting a list of [Filter]s to a single [Filter] or [ListQueryParams].
extension FilterListToListQueryExtension<T> on Iterable<Filter<T>> {
  /// Combines multiple filters into a [ListQueryParams] object using an [And] filter.
  ListQueryParams<T> toListQuery({
    String? search,
    Sort<T>? sort,
    int? limit,
    int? offset,
    Map<String, dynamic>? params,
  }) {
    return ListQueryParams<T>.fromTrusted(
      filter: And<T>(toList()),
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

/// Trust-boundary wire codec for [ListQueryParams] (v3 generic value types get
/// no generated codec).
extension ListQueryParamsWireCodec<T> on ListQueryParams<T> {
  /// Serialize to a wire map. [toElement] encodes a `T` element (unused here —
  /// `filter`/`sort` use their converters).
  Map<String, dynamic> toWire([Object? Function(T value)? toElement]) => {
    'search': search,
    'limit': limit,
    'offset': offset,
    'params': params,
    if (filter != null) 'filter': FilterConverter.toJson(filter!),
    if (sort != null) 'sort': SortConverter.toJson(sort!),
  };
}

/// Decode a [ListQueryParams] from a wire map.
///
/// [fields] / [resolveField] carry typed `Field<T, dynamic>` context so a
/// decoded [Filter]/[Sort] binds to a field of [T]. Without them the converter
/// builds a fallback `Field<dynamic, dynamic>` whose getter only reads
/// `Map<String, dynamic>` entities and throws `StateError` for typed ones —
/// the `as Filter<T>?` / `as Sort<T>?` cast cannot catch that (review #2179).
ListQueryParams<T> listQueryParamsFromWire<T>(
  Map<String, dynamic> raw,
  T Function(Object? json) fromElement, [
  Map<String, Field<T, dynamic>>? fields,
  FieldResolver<T>? resolveField,
]) {
  return ListQueryParams<T>.fromTrusted(
    search: raw['search'] as String?,
    limit: raw['limit'] as int?,
    offset: raw['offset'] as int?,
    params: raw['params'] as Map<String, dynamic>?,
    filter: raw['filter'] != null
        ? FilterConverter.fromJsonTyped<T>(
            raw['filter'] as Map<String, dynamic>,
            fields,
            resolveField,
          )
        : null,
    sort: raw['sort'] != null
        ? SortConverter.fromJsonTyped<T>(
            raw['sort'] as Map<String, dynamic>,
            fields,
            resolveField,
          )
        : null,
  );
}
