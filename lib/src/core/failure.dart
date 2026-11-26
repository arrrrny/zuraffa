import 'package:zorphy_annotation/zorphy_annotation.dart';

part '../../_br_/src/core/failure.part.dart';

/// Polymorphic application failure taxonomy (v8, ZFA-001).
///
/// A closed `@ZorphyUnion` of ten sibling variants. Every variant exposes
/// [message], [traceId], [isRetryable] and [code]; the union root supplies the
/// trust-boundary [AppFailure.fromWire]/[toWire] codec with discriminator
/// dispatch, one const redirecting factory per variant (`AppFailure.network`,
/// `AppFailure.timeout`, … — also reachable through Dart 3 dot-shorthand as
/// `.network(...)`), and the [AppFailure.from] classifier.
///
/// Construct a variant through its root factory (`AppFailure.network(...)`) or
/// the variant's own `fromTrusted`; decode one with [AppFailure.fromWire].
@ZorphyUnion()
abstract class $AppFailure {
  /// Human-readable error message.
  String get message;

  /// Correlation id of the trace that produced this failure, when known.
  String? get traceId;

  /// Whether the failed operation may be retried unchanged.
  @ZorphyDomainBool()
  bool get isRetryable;

  /// Machine-readable code, e.g. a GraphQL error type name.
  String? get code;

  factory $AppFailure.network({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    int? statusCode,
  }) => $NetworkFailure(message: message, traceId: traceId, isRetryable: isRetryable, code: code, statusCode: statusCode);

  factory $AppFailure.timeout({
    required String message,
    String? traceId,
    bool isRetryable = true,
    String? code,
    Duration? timeout,
  }) => $TimeoutFailure(message: message, traceId: traceId, isRetryable: isRetryable, code: code, timeout: timeout);

  factory $AppFailure.boundaryViolation({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    List<FieldViolation> violations = const [],
  }) => $BoundaryViolationFailure(message: message, traceId: traceId, isRetryable: isRetryable, code: code, violations: violations);

  factory $AppFailure.policyDenied({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    String reason = 'permission',
  }) => $PolicyDeniedFailure(message: message, traceId: traceId, isRetryable: isRetryable, code: code, reason: reason);

  factory $AppFailure.notFound({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    String? resourceType,
    String? resourceId,
  }) => $NotFoundFailure(message: message, traceId: traceId, isRetryable: isRetryable, code: code, resourceType: resourceType, resourceId: resourceId);

  factory $AppFailure.conflict({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) => $ConflictFailure(message: message, traceId: traceId, isRetryable: isRetryable, code: code, localPatchWire: localPatchWire, remotePatchWire: remotePatchWire);

  factory $AppFailure.cancelled({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
  }) => $CancelledFailure(message: message, traceId: traceId, isRetryable: isRetryable, code: code);

  factory $AppFailure.interrupted({
    required String message,
    String? traceId,
    bool isRetryable = true,
    String? code,
    String? intentDigest,
  }) => $InterruptedFailure(message: message, traceId: traceId, isRetryable: isRetryable, code: code, intentDigest: intentDigest);

  factory $AppFailure.storage({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    String layer = 'cache',
  }) => $StorageFailure(message: message, traceId: traceId, isRetryable: isRetryable, code: code, layer: layer);

  factory $AppFailure.unexpected({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    String? cause,
    String? stackTrace,
  }) => $UnexpectedFailure(message: message, traceId: traceId, isRetryable: isRetryable, code: code, cause: cause, stackTrace: stackTrace);

  /// Classify an arbitrary [error] into the most specific [AppFailure] variant.
  ///
  /// An [AppFailure] passes through unchanged. Detection order: network, then
  /// timeout, then not-found, then auth/policy (an input matching both
  /// "403 forbidden" and "validation failed" stays an authorization failure so
  /// its callers keep seeing the policy-denied case), then validation, then
  /// conflict, then server/storage, then the unexpected fallback.
  factory $AppFailure.from(Object error, [StackTrace? stackTrace]) {
    if (error is $AppFailure) return error;
    final message = error.toString();
    final lower = message.toLowerCase();

    bool hasStatus(int code) => RegExp(
      r'(?:^|\s|:)' '$code' r'(?:$|\s|:)',
    ).hasMatch(lower);

    if (lower.contains('socketexception') ||
        (lower.contains('connection') &&
            RegExp(r'refused|reset|closed|timeout|error').hasMatch(lower)) ||
        lower.contains('network is unreachable') ||
        lower.contains('no internet') ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated') ||
        lower.contains('handshakeexception') ||
        hasStatus(500) ||
        lower.contains('rate limit')) {
      return $AppFailure.network(message: message);
    }

    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded')) {
      return $AppFailure.timeout(message: message);
    }

    if (hasStatus(404) ||
        (lower.contains('not found') && !lower.contains('exception')) ||
        lower.contains('does not exist')) {
      return $AppFailure.notFound(message: message);
    }

    if (hasStatus(401) ||
        lower.contains('unauthorized') ||
        lower.contains('unauthenticated') ||
        lower.contains('invalid token') ||
        lower.contains('token expired')) {
      return $AppFailure.policyDenied(message: message, reason: 'unauthenticated');
    }
    if (hasStatus(403) || lower.contains('forbidden')) {
      return $AppFailure.policyDenied(message: message, reason: 'forbidden');
    }

    if (lower.contains('formatexception') ||
        lower.contains('argumenterror') ||
        lower.contains('rangeerror') ||
        lower.contains('invalid argument') ||
        lower.contains('validation failed')) {
      return $AppFailure.boundaryViolation(message: message);
    }

    if (hasStatus(409) ||
        lower.contains('conflict') ||
        lower.contains('duplicate') ||
        lower.contains('already exists')) {
      return $AppFailure.conflict(message: message);
    }

    if (hasStatus(502) ||
        hasStatus(503) ||
        hasStatus(504) ||
        lower.contains('internal server error') ||
        lower.contains('bad gateway') ||
        lower.contains('service unavailable')) {
      return $AppFailure.network(message: message);
    }

    if (lower.contains('hiveerror') ||
        lower.contains('sqflite') ||
        (lower.contains('database') && lower.contains('exception'))) {
      return $AppFailure.storage(message: message, layer: 'database');
    }
    if (lower.contains('cache') && lower.contains('exception')) {
      return $AppFailure.storage(message: message, layer: 'cache');
    }

    return $AppFailure.unexpected(
      message: message,
      cause: error.toString(),
      stackTrace: stackTrace?.toString(),
    );
  }
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
  @override
  final String? code;

  /// HTTP status code when the failure originates from an HTTP transport.
  final int? statusCode;

  const $NetworkFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.code,
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
  @override
  final String? code;
  final Duration? timeout;

  const $TimeoutFailure({
    required this.message,
    this.traceId,
    this.isRetryable = true,
    this.code,
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
  @override
  final String? code;

  /// Every violated field, each tagged with a JSON Pointer path.
  final List<FieldViolation> violations;

  const $BoundaryViolationFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.code,
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
  @override
  final String? code;

  /// Why the policy denied the operation (`permission`, `unauthenticated`,
  /// `forbidden`, a rule name, …).
  final String reason;

  const $PolicyDeniedFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.code,
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
  @override
  final String? code;
  final String? resourceType;
  final String? resourceId;

  const $NotFoundFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.code,
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
  @override
  final String? code;
  final Map<String, Object?>? localPatchWire;
  final Map<String, Object?>? remotePatchWire;

  const $ConflictFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.code,
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
  @override
  final String? code;

  const $CancelledFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.code,
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
  @override
  final String? code;
  final String? intentDigest;

  const $InterruptedFailure({
    required this.message,
    this.traceId,
    this.isRetryable = true,
    this.code,
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
  @override
  final String? code;

  /// The storage layer that failed (`cache`, `database`, …).
  final String layer;

  const $StorageFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.code,
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
  @override
  final String? code;

  /// Stringified originating error (diagnostic).
  final String? cause;

  /// Stringified stack trace of the originating error (diagnostic).
  final String? stackTrace;

  const $UnexpectedFailure({
    required this.message,
    this.traceId,
    this.isRetryable = false,
    this.code,
    this.cause,
    this.stackTrace,
  });
}

/// The stack trace to attach when reporting [failure].
///
/// An [UnexpectedFailure] carries the original throw site in its string
/// [stackTrace]; that is more useful to a reporter than the stack captured
/// where the already-built failure was caught and rethrown. Other variants
/// have no stored trace, so the caught trace is used unchanged.
StackTrace? reportedFailureStackTrace(AppFailure failure, StackTrace? caught) {
  if (failure is UnexpectedFailure && failure.stackTrace != null) {
    return StackTrace.fromString(failure.stackTrace!);
  }
  return caught;
}

/// Extension to convert exceptions to failures.
extension ExceptionToFailure on Exception {
  /// Convert this exception to an [AppFailure].
  AppFailure toFailure([StackTrace? stackTrace]) =>
      AppFailure.from(this, stackTrace);
}

/// Extension to convert errors to failures.
extension ErrorToFailure on Error {
  /// Convert this error to an [AppFailure].
  AppFailure toFailure([StackTrace? stackTrace]) =>
      AppFailure.from(this, stackTrace ?? this.stackTrace);
}
