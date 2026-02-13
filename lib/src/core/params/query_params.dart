import 'package:zorphy/zorphy.dart';

import 'converters/filter_converter.dart';
import 'params.dart';

part 'query_params.zorphy.dart';

part 'query_params.g.dart';

/// Parameters for querying a single entity by a field (usually ID or slug).
///
/// The type parameter [T] represents the entity type being queried,
/// enabling type-safe [Filter] references when the entity has filterable fields.
@Zorphy(generateJson: true, generateFilter: true)
abstract class $QueryParams<T> {
  const $QueryParams();

  /// Type-safe filter to identify the entity.
  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: FilterConverter.toJson,
    fromJson: FilterConverter.fromJson,
  )
  Filter<T>? get filter;

  /// Optional additional parameters for the query.
  $Params? get params;
}

/// Extension to query a single entity from an iterable using QueryParams.
extension QueryParamsExtension<T> on Iterable<T> {
  /// Query a single entity matching the filter.
  /// Throws if no entity matches.
  T query(QueryParams<T>? params) {
    if (params?.filter == null) {
      return first;
    }
    return where((item) => params!.filter!.matches(item)).first;
  }
}
