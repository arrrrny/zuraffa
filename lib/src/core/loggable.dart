import 'package:logging/logging.dart';

/// Mixin that provides a [Logger] instance to a class.
///
/// This mixin automatically creates a logger with the class's runtime type
/// as the logger name, making it easy to add logging capabilities to any class.
///
/// ## Example
/// ```dart
/// class MyRepository with Loggable {
///   Future<void> doSomething() async {
///     logger.info('Starting operation');
///     // ... do work
///     logger.fine('Completed successfully');
///   }
/// }
/// ```
mixin Loggable {
  late final Logger _logger = Logger(runtimeType.toString());

  /// Logger instance for this class.
  ///
  /// The logger name is automatically set to the class's runtime type,
  /// making it easy to filter logs by class name.
  Logger get logger => _logger;
}
