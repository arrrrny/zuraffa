import 'package:meta/meta.dart';

/// Base class for all parameter types in the application.
///
/// Provides a polymorphic hierarchy for parameter passing:
/// - [NoParams]: For operations that don't require parameters
/// - [Params]: For generic map-based parameters
/// - [QueryParams]: For type-safe entity queries with filters
///
/// Example:
/// ```dart
/// void processRequest(RequestParams params) {
///   switch (params) {
///     case NoParams():
///       // Handle no parameters
///       break;
///     case QueryParams():
///       // Handle query parameters
///       break;
///   }
/// }
/// ```
@immutable
abstract base class RequestParams {
  /// Private constructor to prevent direct instantiation.
  const RequestParams();

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || runtimeType == other.runtimeType;
}
