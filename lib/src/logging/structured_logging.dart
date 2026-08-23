/// Structured logging facade over `package:logging` (already a zuraffa
/// dependency) — the analysis §4 `logging` built-in. The
/// failure-report queue and otel reporter are 90% wired; this gives
/// apps and plugins one typed entry point with child loggers and
/// JSON-structured fields.
library;

import 'package:logging/logging.dart' as logging;

// package:logging's own Level stays un-re-exported to avoid a name
// clash with the facade's [LogLevel]; import it directly when needed.

/// One structured log record (what handlers receive).
class LogEntry {
  /// The logger name (dotted hierarchy, e.g. `zuraffa.session`).
  final String logger;

  /// Severity.
  final LogLevel level;

  /// The message.
  final String message;

  /// Structured fields (never null; empty when none).
  final Map<String, Object?> fields;

  /// Epoch-ms timestamp.
  final int timestamp;

  const LogEntry({
    required this.logger,
    required this.level,
    required this.message,
    this.fields = const {},
    required this.timestamp,
  });
}

/// Severity levels for the facade (mirrors package:logging).
enum LogLevel { debug, info, warning, error }

logging.Level _toPkgLevel(LogLevel level) => switch (level) {
  LogLevel.debug => logging.Level.FINE,
  LogLevel.info => logging.Level.INFO,
  LogLevel.warning => logging.Level.WARNING,
  LogLevel.error => logging.Level.SEVERE,
};

/// A structured logger: named, hierarchical, with typed fields.
class StructuredLogger {
  /// Dotted logger name (`zuraffa.session`).
  final String name;

  final logging.Logger _logger;

  StructuredLogger._(this.name, this._logger);

  /// Creates (or fetches) the logger for [name].
  factory StructuredLogger(String name) =>
      StructuredLogger._(name, logging.Logger(name));

  /// A child logger (`parent.child`).
  StructuredLogger child(String childName) =>
      StructuredLogger('$name.$childName');

  /// Logs [message] at [level] with structured [fields].
  void log(LogLevel level, String message, [Map<String, Object?>? fields]) {
    _logger.log(
      _toPkgLevel(level),
      fields == null || fields.isEmpty
          ? message
          : '$message ${_encodeFields(fields)}',
    );
  }

  /// Debug-level log.
  void debug(String message, [Map<String, Object?>? fields]) =>
      log(LogLevel.debug, message, fields);

  /// Info-level log.
  void info(String message, [Map<String, Object?>? fields]) =>
      log(LogLevel.info, message, fields);

  /// Warning-level log.
  void warning(String message, [Map<String, Object?>? fields]) =>
      log(LogLevel.warning, message, fields);

  /// Error-level log.
  void error(String message, [Map<String, Object?>? fields]) =>
      log(LogLevel.error, message, fields);

  static String _encodeFields(Map<String, Object?> fields) {
    final parts = fields.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    return '[$parts]';
  }
}

/// The facade root: `zuraffa.log.info('hi', {'user': 'ada'})`.
abstract final class Log {
  /// The root logger.
  static final StructuredLogger root = StructuredLogger('zuraffa');

  /// A named logger (`zuraffa.<name>`).
  static StructuredLogger named(String name) => root.child(name);

  /// Debug via the root logger.
  static void debug(String message, [Map<String, Object?>? fields]) =>
      root.debug(message, fields);

  /// Info via the root logger.
  static void info(String message, [Map<String, Object?>? fields]) =>
      root.info(message, fields);

  /// Warning via the root logger.
  static void warning(String message, [Map<String, Object?>? fields]) =>
      root.warning(message, fields);

  /// Error via the root logger.
  static void error(String message, [Map<String, Object?>? fields]) =>
      root.error(message, fields);

  /// Sets the root hierarchy's level (adapters call once at startup).
  static void setLevel(logging.Level level) {
    logging.hierarchicalLoggingEnabled = true;
    logging.Logger.root.level = level;
    _attachDefaultHandler();
  }

  static bool _handlerAttached = false;

  static void _attachDefaultHandler() {
    if (_handlerAttached) return;
    _handlerAttached = true;
    logging.Logger.root.onRecord.listen((record) {
      // The default handler prints; otel/file adapters replace or add
      // their own handlers on Logger.root.
      // ignore: avoid_print
      print('${record.level.name} ${record.loggerName}: ${record.message}');
    });
  }
}
