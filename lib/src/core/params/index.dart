/// Zuraffa parameter types for UseCases.
///
/// These parameter types provide type-safe ways to pass data to UseCases:
/// - [NoParams] - For UseCases that don't need parameters
/// - [Params] - Generic map-based parameters
/// - [QueryParams] - For querying a single entity
/// - [ListQueryParams] - For querying lists with filtering, sorting, pagination
/// - [CreateParams] - For creating entities
/// - [UpdateParams] - For updating entities
/// - [DeleteParams] - For deleting entities
/// - [InitializationParams] - For repository/data source initialization
library;

export 'no_params.dart';
export 'params.dart';
export 'query_params.dart';
export 'list_query_params.dart';
export 'create_params.dart';
export 'update_params.dart';
export 'delete_params.dart';
export 'initialization_params.dart';
