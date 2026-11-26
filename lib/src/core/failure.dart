import 'package:zorphy_annotation/zorphy_annotation.dart';

part '../../_br_/src/core/failure.part.dart';

/// Polymorphic application failure taxonomy (v8, ZFA-001).
///
/// A closed `@ZorphyUnion` of ten sibling variants. Every variant exposes
/// [message], [traceId] and [isRetryable]; the union root supplies the
/// trust-boundary `fromWire`/`toWire` codec and discriminator dispatch.
///
/// The v2 taxonomy's seventeen concrete classes were folded into these ten
/// variants (see the deprecated forwarding factories below and the migration
/// table on issue #2149). Construct a variant through its factory
/// (`AppFailure.network(...)`, `AppFailure.timeout(...)`, …) or decode one
/// with [AppFailure.fromWire].
@ZorphyUnion()
abstract class $AppFailure {
  /// Human-readable error message.
  String get message;

  /// Correlation id of the trace that produced this failure, when known.
  String? get traceId;

  /// Whether the failed operation may be retried unchanged.
  @ZorphyDomainBool()
  bool get isRetryable;
}

@ZorphyValue()
class $NetworkFailure implements $AppFailure {
  @override
  final String message;
  @override
  final String? traceId;
  @override
  @ZorphyDomainBool()
  final bool isRetryable;

  /// HTTP status code carried over from the v2 `ServerFailure.statusCode`.
  final int? statusCode;

  const $NetworkFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.statusCode,
  });
}

@ZorphyValue()
class $TimeoutFailure implements $AppFailure {
  @override
  final String message;
  @override
  final String? traceId;
  @override
  @ZorphyDomainBool()
  final bool isRetryable;
  final Duration? timeout;

  const $TimeoutFailure({
    required this.message,
    this.traceId,
    this.isRetryable = true,
    this.timeout,
  });
}

@ZorphyValue()
class $BoundaryViolationFailure implements $AppFailure {
  @override
  final String message;
  @override
  final String? traceId;
  @override
  @ZorphyDomainBool()
  final bool isRetryable;
  final List<FieldViolation> violations;

  const $BoundaryViolationFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.violations = const [],
  });
}

@ZorphyValue()
class $PolicyDeniedFailure implements $AppFailure {
  @override
  final String message;
  @override
  final String? traceId;
  @override
  @ZorphyDomainBool()
  final bool isRetryable;
  final String reason;

  const $PolicyDeniedFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.reason = 'permission',
  });
}

@ZorphyValue()
class $NotFoundFailure implements $AppFailure {
  @override
  final String message;
  @override
  final String? traceId;
  @override
  @ZorphyDomainBool()
  final bool isRetryable;
  final String? resourceType;
  final String? resourceId;

  const $NotFoundFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.resourceType,
    this.resourceId,
  });
}

@ZorphyValue()
class $ConflictFailure implements $AppFailure {
  @override
  final String message;
  @override
  final String? traceId;
  @override
  @ZorphyDomainBool()
  final bool isRetryable;
  final Map<String, Object?>? localPatchWire;
  final Map<String, Object?>? remotePatchWire;

  const $ConflictFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.localPatchWire,
    this.remotePatchWire,
  });
}

@ZorphyValue()
class $CancelledFailure implements $AppFailure {
  @override
  final String message;
  @override
  final String? traceId;
  @override
  @ZorphyDomainBool()
  final bool isRetryable;

  const $CancelledFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
  });
}

@ZorphyValue()
class $InterruptedFailure implements $AppFailure {
  @override
  final String message;
  @override
  final String? traceId;
  @override
  @ZorphyDomainBool()
  final bool isRetryable;
  final String? intentDigest;

  const $InterruptedFailure({
    required this.message,
    this.traceId,
    this.isRetryable = true,
    this.intentDigest,
  });
}

@ZorphyValue()
class $StorageFailure implements $AppFailure {
  @override
  final String message;
  @override
  final String? traceId;
  @override
  @ZorphyDomainBool()
  final bool isRetryable;
  final String layer;

  const $StorageFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.layer = 'cache',
  });
}

@ZorphyValue()
class $UnexpectedFailure implements $AppFailure {
  @override
  final String message;
  @override
  final String? traceId;
  @override
  @ZorphyDomainBool()
  final bool isRetryable;

  /// Stringified originating error/cause carried over from v2 (diagnostic).
  final String? cause;

  /// Stringified stack trace carried over from v2 (diagnostic).
  final String? stackTrace;

  const $UnexpectedFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.cause,
    this.stackTrace,
  });
}

/// Positional-message constructors for the ten [AppFailure] variants.
///
/// These exist so the v2 call sites (`ServerFailure(...)`, `AppFailure.network(...)`,
/// …) migrate by a pure prefix rename: each helper's named-parameter set is a
/// SUPERSET of the old constructor/factory arguments, so legacy arguments
/// (`statusCode`, `stackTrace`, `cause`, `code`, `conflictType`, …) are
/// accepted and ignored rather than rewritten. The generated `@ZorphyUnion`
/// root cannot carry static factories, so these top-level helpers are the
/// construction API.
NetworkFailure networkFailure(
  String message, {
  int? statusCode,
  StackTrace? stackTrace,
  Object? cause,
  String? code,
  String? traceId,
  bool isRetryable = false,
  dynamic details,
}) => NetworkFailure.fromTrusted(
  message: message,
  traceId: traceId,
  isRetryable: isRetryable,
  statusCode: statusCode,
);

/// See [networkFailure].
TimeoutFailure timeoutFailure(
  String message, {
  Duration? timeout,
  StackTrace? stackTrace,
  Object? cause,
  String? code,
  String? traceId,
  bool isRetryable = true,
}) => TimeoutFailure.fromTrusted(
  message: message,
  traceId: traceId,
  isRetryable: isRetryable,
  timeout: timeout,
);

/// See [networkFailure].
BoundaryViolationFailure boundaryViolationFailure(
  String message, {
  Map<String, List<String>>? fieldErrors,
  List<FieldViolation> violations = const [],
  StackTrace? stackTrace,
  Object? cause,
  String? code,
  String? traceId,
  bool isRetryable = false,
}) => BoundaryViolationFailure.fromTrusted(
  message: message,
  traceId: traceId,
  isRetryable: isRetryable,
  violations: fieldErrors == null
      ? violations
      : [
          for (final entry in fieldErrors.entries)
            for (final msg in entry.value)
              FieldViolation(
                path: '/${entry.key}',
                expected: 'string',
                actual: msg,
              ),
        ],
);

/// See [networkFailure].
PolicyDeniedFailure policyDeniedFailure(
  String message, {
  String? requiredPermission,
  String? policyRule,
  String reason = 'permission',
  StackTrace? stackTrace,
  Object? cause,
  String? code,
  String? traceId,
  bool isRetryable = false,
}) => PolicyDeniedFailure.fromTrusted(
  message: message,
  traceId: traceId,
  isRetryable: isRetryable,
  reason: policyRule != null && policyRule.toLowerCase().contains('cascade')
      ? 'cascadeDepth'
      : reason,
);

/// See [networkFailure].
NotFoundFailure notFoundFailure(
  String message, {
  String? resourceType,
  String? resourceId,
  StackTrace? stackTrace,
  Object? cause,
  String? code,
  String? traceId,
  bool isRetryable = false,
}) => NotFoundFailure.fromTrusted(
  message: message,
  traceId: traceId,
  isRetryable: isRetryable,
  resourceType: resourceType,
  resourceId: resourceId,
);

/// See [networkFailure].
ConflictFailure conflictFailure(
  String message, {
  String? conflictType,
  Map<String, Object?>? localPatchWire,
  Map<String, Object?>? remotePatchWire,
  StackTrace? stackTrace,
  Object? cause,
  String? code,
  String? traceId,
  bool isRetryable = false,
}) => ConflictFailure.fromTrusted(
  message: message,
  traceId: traceId,
  isRetryable: isRetryable,
  localPatchWire: localPatchWire,
  remotePatchWire: remotePatchWire,
);

/// See [networkFailure].
CancelledFailure cancelledFailure([
  String message = 'Operation was cancelled',
]) => CancelledFailure.fromTrusted(message: message, isRetryable: false);

/// See [networkFailure].
InterruptedFailure interruptedFailure(
  String message, {
  String? intentDigest,
  StackTrace? stackTrace,
  Object? cause,
  String? code,
  String? traceId,
  bool isRetryable = true,
}) => InterruptedFailure.fromTrusted(
  message: message,
  traceId: traceId,
  isRetryable: isRetryable,
  intentDigest: intentDigest,
);

/// See [networkFailure].
StorageFailure storageFailure(
  String message, {
  String layer = 'cache',
  StackTrace? stackTrace,
  Object? cause,
  String? code,
  String? traceId,
  bool isRetryable = false,
}) => StorageFailure.fromTrusted(
  message: message,
  traceId: traceId,
  isRetryable: isRetryable,
  layer: layer,
);

/// See [networkFailure].
UnexpectedFailure unexpectedFailure(
  String message, {
  StackTrace? stackTrace,
  Object? cause,
  String? code,
  dynamic details,
  String? traceId,
  bool isRetryable = false,
}) => UnexpectedFailure.fromTrusted(
  message: message,
  traceId: traceId,
  isRetryable: isRetryable,
  cause: cause?.toString(),
  stackTrace: stackTrace?.toString(),
);

/// Classify an arbitrary [error] into the most specific [AppFailure] variant.
///
/// Replaces the v2 `AppFailure.from` body-factory (a body-logic factory cannot
/// live on a generated union root). Detection order mirrors the v2 classifier.
AppFailure appFailureFrom(Object error, [StackTrace? stackTrace]) {
  if (error is AppFailure) return error;
  final message = error.toString();
  final lower = message.toLowerCase();

  bool hasStatus(int code) => RegExp(
    '(?:^|\\s|:)'
    '$code'
    r'(?:$|\s|:)',
  ).hasMatch(lower);

  // Network / server / service-unavailable / rate-limit → network.
  if (lower.contains('socketexception') ||
      (lower.contains('connection') &&
          RegExp(r'refused|reset|closed|timeout|error').hasMatch(lower)) ||
      lower.contains('network is unreachable') ||
      lower.contains('no internet') ||
      lower.contains('failed host lookup') ||
      lower.contains('handshakeexception') ||
      hasStatus(500) ||
      hasStatus(502) ||
      hasStatus(503) ||
      hasStatus(504) ||
      lower.contains('internal server error') ||
      lower.contains('bad gateway') ||
      lower.contains('service unavailable') ||
      lower.contains('rate limit')) {
    return networkFailure(message);
  }

  // Timeout.
  if (lower.contains('timeout') ||
      lower.contains('timed out') ||
      lower.contains('deadline exceeded')) {
    return timeoutFailure(message);
  }

  // Validation / boundary violation.
  if (lower.contains('formatexception') ||
      lower.contains('argumenterror') ||
      lower.contains('rangeerror') ||
      lower.contains('invalid argument') ||
      lower.contains('validation failed')) {
    return boundaryViolationFailure(message);
  }

  // Policy denied (auth / forbidden).
  if (hasStatus(401) ||
      lower.contains('unauthorized') ||
      lower.contains('unauthenticated') ||
      lower.contains('invalid token') ||
      lower.contains('token expired')) {
    return policyDeniedFailure(message, reason: 'unauthenticated');
  }
  if (hasStatus(403) || lower.contains('forbidden')) {
    return policyDeniedFailure(message, reason: 'forbidden');
  }

  // Not found.
  if (hasStatus(404) ||
      (lower.contains('not found') && !lower.contains('exception')) ||
      lower.contains('does not exist')) {
    return notFoundFailure(message);
  }

  // Conflict.
  if (hasStatus(409) ||
      lower.contains('conflict') ||
      lower.contains('duplicate') ||
      lower.contains('already exists')) {
    return conflictFailure(message);
  }

  // Storage (cache / database).
  if (lower.contains('hiveerror') ||
      lower.contains('sqflite') ||
      (lower.contains('database') && lower.contains('exception'))) {
    return storageFailure(message, layer: 'database');
  }
  if (lower.contains('cache') && lower.contains('exception')) {
    return storageFailure(message, layer: 'cache');
  }

  // Fallback.
  return unexpectedFailure(message, cause: error, stackTrace: stackTrace);
}

/// Extension to convert exceptions to failures.
extension ExceptionToFailure on Exception {
  /// Convert this exception to an [AppFailure].
  AppFailure toFailure([StackTrace? stackTrace]) =>
      appFailureFrom(this, stackTrace);
}

/// Extension to convert errors to failures.
extension ErrorToFailure on Error {
  /// Convert this error to an [AppFailure].
  AppFailure toFailure([StackTrace? stackTrace]) =>
      appFailureFrom(this, stackTrace ?? this.stackTrace);
}
