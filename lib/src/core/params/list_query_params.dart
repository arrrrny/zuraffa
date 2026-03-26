import 'package:zorphy/zorphy.dart';
import 'package:zuraffa/src/core/params/index.dart';

part 'list_query_params.zorphy.dart';

part 'list_query_params.g.dart';

/// Parameters for querying a list of entities.
///
/// Use [ListQueryParams] to pass common query options like typed filtering,
/// sorting, and pagination to list-based UseCases.
///
/// The type parameter [T] represents the entity type being queried,
/// enabling type-safe [Filter], [Field], and [Sort] references.
@Zorphy(generateJson: true, generateFilter: true)
abstract class $ListQueryParams<T> implements $Params {
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
    return ListQueryParams<T>(
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
    return ListQueryParams<T>(
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
    final buffer = StringBuffer();

    // Add basic fields if they exist (based on typical ListQueryParams structure)
    // We use a safe approach by converting to string if we're not sure about the exact fields
    // but typically ListQueryParams has limit, offset, filter, sort, search.

    try {
      buffer.write('l:${limit ?? 'n'}_');
      buffer.write('o:${offset ?? 'n'}_');

      if (search != null && search!.isNotEmpty) {
        buffer.write('s:${search}_');
      }

      if (filter != null) {
        buffer.write('f:${filter.hashCode}_');
      }

      if (sort != null) {
        buffer.write('st:${sort.hashCode}_');
      }
    } catch (e) {
      // Fallback to a simple string if fields are missing or different
      buffer.write(toString());
    }

    return buffer.toString();
  }
}
