import 'package:zorphy/zorphy.dart';

import 'converters/filter_converter.dart';
import 'converters/sort_converter.dart';
import 'params.dart';

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
abstract class $ListQueryParams<T> {
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

  /// Optional arbitrary additional parameters as an escape hatch
  $Params? get params;
}
