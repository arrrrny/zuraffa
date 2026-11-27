part of 'failure.dart';

// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

sealed class AppFailure implements ZorphyUnionBase {
  const AppFailure();

  factory AppFailure.network({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    int? statusCode,
  }) => NetworkFailure.fromTrusted(
    message: message,
    traceId: traceId,
    isRetryable: isRetryable,
    code: code,
    statusCode: statusCode,
  );

  factory AppFailure.timeout({
    required String message,
    String? traceId,
    bool isRetryable = true,
    String? code,
    Duration? timeout,
  }) => TimeoutFailure.fromTrusted(
    message: message,
    traceId: traceId,
    isRetryable: isRetryable,
    code: code,
    timeout: timeout,
  );

  factory AppFailure.boundaryViolation({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    List<FieldViolation> violations = const [],
  }) => BoundaryViolationFailure.fromTrusted(
    message: message,
    traceId: traceId,
    isRetryable: isRetryable,
    code: code,
    violations: violations,
  );

  factory AppFailure.policyDenied({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    String reason = 'permission',
  }) => PolicyDeniedFailure.fromTrusted(
    message: message,
    traceId: traceId,
    isRetryable: isRetryable,
    code: code,
    reason: reason,
  );

  factory AppFailure.notFound({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    String? resourceType,
    String? resourceId,
  }) => NotFoundFailure.fromTrusted(
    message: message,
    traceId: traceId,
    isRetryable: isRetryable,
    code: code,
    resourceType: resourceType,
    resourceId: resourceId,
  );

  factory AppFailure.conflict({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) => ConflictFailure.fromTrusted(
    message: message,
    traceId: traceId,
    isRetryable: isRetryable,
    code: code,
    localPatchWire: localPatchWire,
    remotePatchWire: remotePatchWire,
  );

  factory AppFailure.cancelled({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
  }) => CancelledFailure.fromTrusted(
    message: message,
    traceId: traceId,
    isRetryable: isRetryable,
    code: code,
  );

  factory AppFailure.interrupted({
    required String message,
    String? traceId,
    bool isRetryable = true,
    String? code,
    String? intentDigest,
  }) => InterruptedFailure.fromTrusted(
    message: message,
    traceId: traceId,
    isRetryable: isRetryable,
    code: code,
    intentDigest: intentDigest,
  );

  factory AppFailure.storage({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    String layer = 'cache',
  }) => StorageFailure.fromTrusted(
    message: message,
    traceId: traceId,
    isRetryable: isRetryable,
    code: code,
    layer: layer,
  );

  factory AppFailure.unexpected({
    required String message,
    String? traceId,
    bool isRetryable = false,
    String? code,
    String? cause,
    String? stackTrace,
  }) => UnexpectedFailure.fromTrusted(
    message: message,
    traceId: traceId,
    isRetryable: isRetryable,
    code: code,
    cause: cause,
    stackTrace: stackTrace,
  );

  factory AppFailure.from(Object error, [StackTrace? stackTrace]) {
    if (error is AppFailure) return error;
    final message = error.toString();
    final lower = message.toLowerCase();
    bool hasStatus(int code) => RegExp(
      r'(?:^|\s|:)'
      '$code'
      r'(?:$|\s|:)',
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
      return AppFailure.network(message: message);
    }
    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded')) {
      return AppFailure.timeout(message: message);
    }
    if (hasStatus(404) ||
        (lower.contains('not found') && !lower.contains('exception')) ||
        lower.contains('does not exist')) {
      return AppFailure.notFound(message: message);
    }
    if (hasStatus(401) ||
        lower.contains('unauthorized') ||
        lower.contains('unauthenticated') ||
        lower.contains('invalid token') ||
        lower.contains('token expired')) {
      return AppFailure.policyDenied(
        message: message,
        reason: 'unauthenticated',
      );
    }
    if (hasStatus(403) || lower.contains('forbidden')) {
      return AppFailure.policyDenied(message: message, reason: 'forbidden');
    }
    if (lower.contains('formatexception') ||
        lower.contains('argumenterror') ||
        lower.contains('rangeerror') ||
        lower.contains('invalid argument') ||
        lower.contains('validation failed')) {
      return AppFailure.boundaryViolation(message: message);
    }
    if (hasStatus(409) ||
        lower.contains('conflict') ||
        lower.contains('duplicate') ||
        lower.contains('already exists')) {
      return AppFailure.conflict(message: message);
    }
    if (hasStatus(502) ||
        hasStatus(503) ||
        hasStatus(504) ||
        lower.contains('internal server error') ||
        lower.contains('bad gateway') ||
        lower.contains('service unavailable')) {
      return AppFailure.network(message: message);
    }
    if (lower.contains('hiveerror') ||
        lower.contains('sqflite') ||
        (lower.contains('database') && lower.contains('exception'))) {
      return AppFailure.storage(message: message, layer: 'database');
    }
    if (lower.contains('cache') && lower.contains('exception')) {
      return AppFailure.storage(message: message, layer: 'cache');
    }
    return AppFailure.unexpected(
      message: message,
      cause: error.toString(),
      stackTrace: stackTrace?.toString(),
    );
  }

  String get message;
  String? get traceId;
  bool get isRetryable;
  String? get code;
  static ZorphyBoundaryResult<AppFailure> fromWire(Map<String, Object?> raw) {
    final Object? tag = raw['kind'];
    if (tag is String) {
      switch (tag) {
        case 'network_failure':
          return NetworkFailure.fromWire(
            raw,
          ).fold<ZorphyBoundaryResult<AppFailure>>(
            (value) => BoundaryOk<AppFailure>(value),
            (error) => BoundaryErr<AppFailure>(
              targetType: error.targetType,
              violations: error.violations,
            ),
          );
        case 'timeout_failure':
          return TimeoutFailure.fromWire(
            raw,
          ).fold<ZorphyBoundaryResult<AppFailure>>(
            (value) => BoundaryOk<AppFailure>(value),
            (error) => BoundaryErr<AppFailure>(
              targetType: error.targetType,
              violations: error.violations,
            ),
          );
        case 'boundary_violation_failure':
          return BoundaryViolationFailure.fromWire(
            raw,
          ).fold<ZorphyBoundaryResult<AppFailure>>(
            (value) => BoundaryOk<AppFailure>(value),
            (error) => BoundaryErr<AppFailure>(
              targetType: error.targetType,
              violations: error.violations,
            ),
          );
        case 'policy_denied_failure':
          return PolicyDeniedFailure.fromWire(
            raw,
          ).fold<ZorphyBoundaryResult<AppFailure>>(
            (value) => BoundaryOk<AppFailure>(value),
            (error) => BoundaryErr<AppFailure>(
              targetType: error.targetType,
              violations: error.violations,
            ),
          );
        case 'not_found_failure':
          return NotFoundFailure.fromWire(
            raw,
          ).fold<ZorphyBoundaryResult<AppFailure>>(
            (value) => BoundaryOk<AppFailure>(value),
            (error) => BoundaryErr<AppFailure>(
              targetType: error.targetType,
              violations: error.violations,
            ),
          );
        case 'conflict_failure':
          return ConflictFailure.fromWire(
            raw,
          ).fold<ZorphyBoundaryResult<AppFailure>>(
            (value) => BoundaryOk<AppFailure>(value),
            (error) => BoundaryErr<AppFailure>(
              targetType: error.targetType,
              violations: error.violations,
            ),
          );
        case 'cancelled_failure':
          return CancelledFailure.fromWire(
            raw,
          ).fold<ZorphyBoundaryResult<AppFailure>>(
            (value) => BoundaryOk<AppFailure>(value),
            (error) => BoundaryErr<AppFailure>(
              targetType: error.targetType,
              violations: error.violations,
            ),
          );
        case 'interrupted_failure':
          return InterruptedFailure.fromWire(
            raw,
          ).fold<ZorphyBoundaryResult<AppFailure>>(
            (value) => BoundaryOk<AppFailure>(value),
            (error) => BoundaryErr<AppFailure>(
              targetType: error.targetType,
              violations: error.violations,
            ),
          );
        case 'storage_failure':
          return StorageFailure.fromWire(
            raw,
          ).fold<ZorphyBoundaryResult<AppFailure>>(
            (value) => BoundaryOk<AppFailure>(value),
            (error) => BoundaryErr<AppFailure>(
              targetType: error.targetType,
              violations: error.violations,
            ),
          );
        case 'unexpected_failure':
          return UnexpectedFailure.fromWire(
            raw,
          ).fold<ZorphyBoundaryResult<AppFailure>>(
            (value) => BoundaryOk<AppFailure>(value),
            (error) => BoundaryErr<AppFailure>(
              targetType: error.targetType,
              violations: error.violations,
            ),
          );
      }
    }
    return BoundaryErr<AppFailure>(
      targetType: 'AppFailure',
      violations: <FieldViolation>[
        FieldViolation(
          path: '/kind',
          expected:
              'String (one of: network_failure, timeout_failure, boundary_violation_failure, policy_denied_failure, not_found_failure, conflict_failure, cancelled_failure, interrupted_failure, storage_failure, unexpected_failure)',
          actual: _boundaryDescribe(tag),
        ),
      ],
    );
  }

  Map<String, Object?> toWire() {
    final value = this;
    if (value is NetworkFailure) return value.toWire();
    if (value is TimeoutFailure) return value.toWire();
    if (value is BoundaryViolationFailure) return value.toWire();
    if (value is PolicyDeniedFailure) return value.toWire();
    if (value is NotFoundFailure) return value.toWire();
    if (value is ConflictFailure) return value.toWire();
    if (value is CancelledFailure) return value.toWire();
    if (value is InterruptedFailure) return value.toWire();
    if (value is StorageFailure) return value.toWire();
    if (value is UnexpectedFailure) return value.toWire();
    return <String, Object?>{'kind': '$runtimeType'};
  }

  static ZorphyBoundaryResult<AppFailure> fromJson(Map<String, dynamic> json) {
    return AppFailure.fromWire(json);
  }

  Map<String, dynamic> toJson() {
    return toWire();
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [AppFailure].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<AppFailure, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/message' => ZorphyLens<AppFailure, Object?>(
        path: '/message',
        get: (root) => root.message,
        set: (root, value) => switch (root) {
          NetworkFailure _node => _node.copyWith(message: value as String),
          TimeoutFailure _node => _node.copyWith(message: value as String),
          BoundaryViolationFailure _node => _node.copyWith(
            message: value as String,
          ),
          PolicyDeniedFailure _node => _node.copyWith(message: value as String),
          NotFoundFailure _node => _node.copyWith(message: value as String),
          ConflictFailure _node => _node.copyWith(message: value as String),
          CancelledFailure _node => _node.copyWith(message: value as String),
          InterruptedFailure _node => _node.copyWith(message: value as String),
          StorageFailure _node => _node.copyWith(message: value as String),
          UnexpectedFailure _node => _node.copyWith(message: value as String),
        },
      ),
      '/traceId' => ZorphyLens<AppFailure, Object?>(
        path: '/traceId',
        get: (root) => root.traceId,
        set: (root, value) => switch (root) {
          NetworkFailure _node => _node.copyWith(traceId: value as String?),
          TimeoutFailure _node => _node.copyWith(traceId: value as String?),
          BoundaryViolationFailure _node => _node.copyWith(
            traceId: value as String?,
          ),
          PolicyDeniedFailure _node => _node.copyWith(
            traceId: value as String?,
          ),
          NotFoundFailure _node => _node.copyWith(traceId: value as String?),
          ConflictFailure _node => _node.copyWith(traceId: value as String?),
          CancelledFailure _node => _node.copyWith(traceId: value as String?),
          InterruptedFailure _node => _node.copyWith(traceId: value as String?),
          StorageFailure _node => _node.copyWith(traceId: value as String?),
          UnexpectedFailure _node => _node.copyWith(traceId: value as String?),
        },
      ),
      '/isRetryable' => ZorphyLens<AppFailure, Object?>(
        path: '/isRetryable',
        get: (root) => root.isRetryable,
        set: (root, value) => switch (root) {
          NetworkFailure _node => _node.copyWith(isRetryable: value as bool),
          TimeoutFailure _node => _node.copyWith(isRetryable: value as bool),
          BoundaryViolationFailure _node => _node.copyWith(
            isRetryable: value as bool,
          ),
          PolicyDeniedFailure _node => _node.copyWith(
            isRetryable: value as bool,
          ),
          NotFoundFailure _node => _node.copyWith(isRetryable: value as bool),
          ConflictFailure _node => _node.copyWith(isRetryable: value as bool),
          CancelledFailure _node => _node.copyWith(isRetryable: value as bool),
          InterruptedFailure _node => _node.copyWith(
            isRetryable: value as bool,
          ),
          StorageFailure _node => _node.copyWith(isRetryable: value as bool),
          UnexpectedFailure _node => _node.copyWith(isRetryable: value as bool),
        },
      ),
      '/code' => ZorphyLens<AppFailure, Object?>(
        path: '/code',
        get: (root) => root.code,
        set: (root, value) => switch (root) {
          NetworkFailure _node => _node.copyWith(code: value as String?),
          TimeoutFailure _node => _node.copyWith(code: value as String?),
          BoundaryViolationFailure _node => _node.copyWith(
            code: value as String?,
          ),
          PolicyDeniedFailure _node => _node.copyWith(code: value as String?),
          NotFoundFailure _node => _node.copyWith(code: value as String?),
          ConflictFailure _node => _node.copyWith(code: value as String?),
          CancelledFailure _node => _node.copyWith(code: value as String?),
          InterruptedFailure _node => _node.copyWith(code: value as String?),
          StorageFailure _node => _node.copyWith(code: value as String?),
          UnexpectedFailure _node => _node.copyWith(code: value as String?),
        },
      ),
      '/statusCode' => ZorphyLens<AppFailure, Object?>(
        path: '/statusCode',
        get: (root) => switch (root) {
          NetworkFailure _node => _node.statusCode,
          _ => null,
        },
        set: (root, value) => switch (root) {
          NetworkFailure _node => _node.copyWith(statusCode: value as int?),
          _ => root,
        },
      ),
      '/timeout' => ZorphyLens<AppFailure, Object?>(
        path: '/timeout',
        get: (root) => switch (root) {
          TimeoutFailure _node => _node.timeout,
          _ => null,
        },
        set: (root, value) => switch (root) {
          TimeoutFailure _node => _node.copyWith(timeout: value as Duration?),
          _ => root,
        },
      ),
      '/violations' => ZorphyLens<AppFailure, Object?>(
        path: '/violations',
        get: (root) => switch (root) {
          BoundaryViolationFailure _node => _node.violations,
          _ => null,
        },
        set: (root, value) => switch (root) {
          BoundaryViolationFailure _node => _node.copyWith(
            violations: value as List<FieldViolation>,
          ),
          _ => root,
        },
      ),
      '/reason' => ZorphyLens<AppFailure, Object?>(
        path: '/reason',
        get: (root) => switch (root) {
          PolicyDeniedFailure _node => _node.reason,
          _ => null,
        },
        set: (root, value) => switch (root) {
          PolicyDeniedFailure _node => _node.copyWith(reason: value as String),
          _ => root,
        },
      ),
      '/resourceType' => ZorphyLens<AppFailure, Object?>(
        path: '/resourceType',
        get: (root) => switch (root) {
          NotFoundFailure _node => _node.resourceType,
          _ => null,
        },
        set: (root, value) => switch (root) {
          NotFoundFailure _node => _node.copyWith(
            resourceType: value as String?,
          ),
          _ => root,
        },
      ),
      '/resourceId' => ZorphyLens<AppFailure, Object?>(
        path: '/resourceId',
        get: (root) => switch (root) {
          NotFoundFailure _node => _node.resourceId,
          _ => null,
        },
        set: (root, value) => switch (root) {
          NotFoundFailure _node => _node.copyWith(resourceId: value as String?),
          _ => root,
        },
      ),
      '/localPatchWire' => ZorphyLens<AppFailure, Object?>(
        path: '/localPatchWire',
        get: (root) => switch (root) {
          ConflictFailure _node => _node.localPatchWire,
          _ => null,
        },
        set: (root, value) => switch (root) {
          ConflictFailure _node => _node.copyWith(
            localPatchWire: value as Map<String, Object?>?,
          ),
          _ => root,
        },
      ),
      '/remotePatchWire' => ZorphyLens<AppFailure, Object?>(
        path: '/remotePatchWire',
        get: (root) => switch (root) {
          ConflictFailure _node => _node.remotePatchWire,
          _ => null,
        },
        set: (root, value) => switch (root) {
          ConflictFailure _node => _node.copyWith(
            remotePatchWire: value as Map<String, Object?>?,
          ),
          _ => root,
        },
      ),
      '/intentDigest' => ZorphyLens<AppFailure, Object?>(
        path: '/intentDigest',
        get: (root) => switch (root) {
          InterruptedFailure _node => _node.intentDigest,
          _ => null,
        },
        set: (root, value) => switch (root) {
          InterruptedFailure _node => _node.copyWith(
            intentDigest: value as String?,
          ),
          _ => root,
        },
      ),
      '/layer' => ZorphyLens<AppFailure, Object?>(
        path: '/layer',
        get: (root) => switch (root) {
          StorageFailure _node => _node.layer,
          _ => null,
        },
        set: (root, value) => switch (root) {
          StorageFailure _node => _node.copyWith(layer: value as String),
          _ => root,
        },
      ),
      '/cause' => ZorphyLens<AppFailure, Object?>(
        path: '/cause',
        get: (root) => switch (root) {
          UnexpectedFailure _node => _node.cause,
          _ => null,
        },
        set: (root, value) => switch (root) {
          UnexpectedFailure _node => _node.copyWith(cause: value as String?),
          _ => root,
        },
      ),
      '/stackTrace' => ZorphyLens<AppFailure, Object?>(
        path: '/stackTrace',
        get: (root) => switch (root) {
          UnexpectedFailure _node => _node.stackTrace,
          _ => null,
        },
        set: (root, value) => switch (root) {
          UnexpectedFailure _node => _node.copyWith(
            stackTrace: value as String?,
          ),
          _ => root,
        },
      ),
      _ => null,
    };
  }
}

final class NetworkFailure extends AppFailure implements ZorphyValueBase {
  const NetworkFailure.fromTrusted({
    required this.message,
    this.traceId,
    required this.isRetryable,
    this.code,
    this.statusCode,
  });

  @override
  final String message;

  @override
  final String? traceId;

  @override
  final bool isRetryable;

  @override
  final String? code;

  final int? statusCode;

  static const NetworkFailureLenses lenses = NetworkFailureLenses();

  NetworkFailure copyWith({
    String? message,
    Object? traceId = _sentinel,
    bool? isRetryable,
    Object? code = _sentinel,
    Object? statusCode = _sentinel,
  }) {
    return NetworkFailure.fromTrusted(
      message: message ?? this.message,
      traceId: identical(traceId, _sentinel)
          ? this.traceId
          : traceId as String?,
      isRetryable: isRetryable ?? this.isRetryable,
      code: identical(code, _sentinel) ? this.code : code as String?,
      statusCode: identical(statusCode, _sentinel)
          ? this.statusCode
          : statusCode as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkFailure &&
        this.message == other.message &&
        this.traceId == other.traceId &&
        this.isRetryable == other.isRetryable &&
        this.code == other.code &&
        this.statusCode == other.statusCode;
  }

  @override
  int get hashCode =>
      Object.hashAll([message, traceId, isRetryable, code, statusCode]);

  @override
  String toString() =>
      'NetworkFailure(message: $message, traceId: $traceId, isRetryable: $isRetryable, code: $code, statusCode: $statusCode)';

  static ZorphyBoundaryResult<NetworkFailure> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_message = raw['message'];
    String? _message;
    _message = _boundaryAs<String>(raw_message, '/message', violations);
    final Object? raw_traceId = raw['traceId'];
    String? _traceId;
    if (raw_traceId != null) {
      _traceId = _boundaryAs<String>(raw_traceId, '/traceId', violations);
    }
    final Object? raw_isRetryable = raw['isRetryable'];
    bool? _isRetryable;
    _isRetryable = _boundaryAs<bool>(
      raw_isRetryable,
      '/isRetryable',
      violations,
    );
    final Object? raw_code = raw['code'];
    String? _code;
    if (raw_code != null) {
      _code = _boundaryAs<String>(raw_code, '/code', violations);
    }
    final Object? raw_statusCode = raw['statusCode'];
    int? _statusCode;
    if (raw_statusCode != null) {
      _statusCode = _boundaryAs<int>(raw_statusCode, '/statusCode', violations);
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<NetworkFailure>(
        targetType: 'NetworkFailure',
        violations: violations,
      );
    }
    return BoundaryOk<NetworkFailure>(
      NetworkFailure.fromTrusted(
        message: _message!,
        traceId: _traceId,
        isRetryable: _isRetryable!,
        code: _code,
        statusCode: _statusCode,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{'kind': 'network_failure'};
    map['message'] = this.message;
    final _traceId = this.traceId;
    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    map['isRetryable'] = this.isRetryable;
    final _code = this.code;
    if (_code != null) {
      map['code'] = _code;
    }
    final _statusCode = this.statusCode;
    if (_statusCode != null) {
      map['statusCode'] = _statusCode;
    }
    return map;
  }

  static ZorphyBoundaryResult<NetworkFailure> fromJson(
    Map<String, dynamic> json,
  ) {
    return NetworkFailure.fromWire(json);
  }

  Map<String, dynamic> toJson() {
    return toWire();
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [NetworkFailure].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<NetworkFailure, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/message' => ZorphyLens<NetworkFailure, Object?>(
        path: '/message',
        get: (root) => root.message,
        set: (root, value) => root.copyWith(message: value as String),
      ),
      '/traceId' => ZorphyLens<NetworkFailure, Object?>(
        path: '/traceId',
        get: (root) => root.traceId,
        set: (root, value) => root.copyWith(traceId: value as String?),
      ),
      '/isRetryable' => ZorphyLens<NetworkFailure, Object?>(
        path: '/isRetryable',
        get: (root) => root.isRetryable,
        set: (root, value) => root.copyWith(isRetryable: value as bool),
      ),
      '/code' => ZorphyLens<NetworkFailure, Object?>(
        path: '/code',
        get: (root) => root.code,
        set: (root, value) => root.copyWith(code: value as String?),
      ),
      '/statusCode' => ZorphyLens<NetworkFailure, Object?>(
        path: '/statusCode',
        get: (root) => root.statusCode,
        set: (root, value) => root.copyWith(statusCode: value as int?),
      ),
      _ => null,
    };
  }
}

final class TimeoutFailure extends AppFailure implements ZorphyValueBase {
  const TimeoutFailure.fromTrusted({
    required this.message,
    this.traceId,
    required this.isRetryable,
    this.code,
    this.timeout,
  });

  @override
  final String message;

  @override
  final String? traceId;

  @override
  final bool isRetryable;

  @override
  final String? code;

  final Duration? timeout;

  static const TimeoutFailureLenses lenses = TimeoutFailureLenses();

  TimeoutFailure copyWith({
    String? message,
    Object? traceId = _sentinel,
    bool? isRetryable,
    Object? code = _sentinel,
    Object? timeout = _sentinel,
  }) {
    return TimeoutFailure.fromTrusted(
      message: message ?? this.message,
      traceId: identical(traceId, _sentinel)
          ? this.traceId
          : traceId as String?,
      isRetryable: isRetryable ?? this.isRetryable,
      code: identical(code, _sentinel) ? this.code : code as String?,
      timeout: identical(timeout, _sentinel)
          ? this.timeout
          : timeout as Duration?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeoutFailure &&
        this.message == other.message &&
        this.traceId == other.traceId &&
        this.isRetryable == other.isRetryable &&
        this.code == other.code &&
        this.timeout == other.timeout;
  }

  @override
  int get hashCode =>
      Object.hashAll([message, traceId, isRetryable, code, timeout]);

  @override
  String toString() =>
      'TimeoutFailure(message: $message, traceId: $traceId, isRetryable: $isRetryable, code: $code, timeout: $timeout)';

  static ZorphyBoundaryResult<TimeoutFailure> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_message = raw['message'];
    String? _message;
    _message = _boundaryAs<String>(raw_message, '/message', violations);
    final Object? raw_traceId = raw['traceId'];
    String? _traceId;
    if (raw_traceId != null) {
      _traceId = _boundaryAs<String>(raw_traceId, '/traceId', violations);
    }
    final Object? raw_isRetryable = raw['isRetryable'];
    bool? _isRetryable;
    _isRetryable = _boundaryAs<bool>(
      raw_isRetryable,
      '/isRetryable',
      violations,
    );
    final Object? raw_code = raw['code'];
    String? _code;
    if (raw_code != null) {
      _code = _boundaryAs<String>(raw_code, '/code', violations);
    }
    final Object? raw_timeout = raw['timeout'];
    Duration? _timeout;
    if (raw_timeout != null) {
      _timeout = _boundaryAs<Duration>(raw_timeout, '/timeout', violations);
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<TimeoutFailure>(
        targetType: 'TimeoutFailure',
        violations: violations,
      );
    }
    return BoundaryOk<TimeoutFailure>(
      TimeoutFailure.fromTrusted(
        message: _message!,
        traceId: _traceId,
        isRetryable: _isRetryable!,
        code: _code,
        timeout: _timeout,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{'kind': 'timeout_failure'};
    map['message'] = this.message;
    final _traceId = this.traceId;
    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    map['isRetryable'] = this.isRetryable;
    final _code = this.code;
    if (_code != null) {
      map['code'] = _code;
    }
    final _timeout = this.timeout;
    if (_timeout != null) {
      map['timeout'] = _timeout;
    }
    return map;
  }

  static ZorphyBoundaryResult<TimeoutFailure> fromJson(
    Map<String, dynamic> json,
  ) {
    return TimeoutFailure.fromWire(json);
  }

  Map<String, dynamic> toJson() {
    return toWire();
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [TimeoutFailure].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<TimeoutFailure, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/message' => ZorphyLens<TimeoutFailure, Object?>(
        path: '/message',
        get: (root) => root.message,
        set: (root, value) => root.copyWith(message: value as String),
      ),
      '/traceId' => ZorphyLens<TimeoutFailure, Object?>(
        path: '/traceId',
        get: (root) => root.traceId,
        set: (root, value) => root.copyWith(traceId: value as String?),
      ),
      '/isRetryable' => ZorphyLens<TimeoutFailure, Object?>(
        path: '/isRetryable',
        get: (root) => root.isRetryable,
        set: (root, value) => root.copyWith(isRetryable: value as bool),
      ),
      '/code' => ZorphyLens<TimeoutFailure, Object?>(
        path: '/code',
        get: (root) => root.code,
        set: (root, value) => root.copyWith(code: value as String?),
      ),
      '/timeout' => ZorphyLens<TimeoutFailure, Object?>(
        path: '/timeout',
        get: (root) => root.timeout,
        set: (root, value) => root.copyWith(timeout: value as Duration?),
      ),
      _ => null,
    };
  }
}

final class BoundaryViolationFailure extends AppFailure
    implements ZorphyValueBase {
  BoundaryViolationFailure.fromTrusted({
    required this.message,
    this.traceId,
    required this.isRetryable,
    this.code,
    required List<FieldViolation> violations,
  }) : violations = List<FieldViolation>.of(violations);

  @override
  final String message;

  @override
  final String? traceId;

  @override
  final bool isRetryable;

  @override
  final String? code;

  final List<FieldViolation> violations;

  static const BoundaryViolationFailureLenses lenses =
      BoundaryViolationFailureLenses();

  BoundaryViolationFailure copyWith({
    String? message,
    Object? traceId = _sentinel,
    bool? isRetryable,
    Object? code = _sentinel,
    List<FieldViolation>? violations,
  }) {
    return BoundaryViolationFailure.fromTrusted(
      message: message ?? this.message,
      traceId: identical(traceId, _sentinel)
          ? this.traceId
          : traceId as String?,
      isRetryable: isRetryable ?? this.isRetryable,
      code: identical(code, _sentinel) ? this.code : code as String?,
      violations: violations ?? this.violations,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BoundaryViolationFailure &&
        this.message == other.message &&
        this.traceId == other.traceId &&
        this.isRetryable == other.isRetryable &&
        this.code == other.code &&
        BoundaryViolationFailure._zorphyCollectionEquals(
          this.violations,
          other.violations,
        );
  }

  @override
  int get hashCode => Object.hashAll([
    message,
    traceId,
    isRetryable,
    code,
    BoundaryViolationFailure._zorphyCollectionHash(violations),
  ]);

  @override
  String toString() =>
      'BoundaryViolationFailure(message: $message, traceId: $traceId, isRetryable: $isRetryable, code: $code, violations: $violations)';

  static bool _zorphyCollectionEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    if (a is Set && b is Set) {
      if (a.length != b.length) return false;
      return a.every(b.contains);
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  static int _zorphyCollectionHash(Object? value) {
    if (value is List) return Object.hashAll(value);
    if (value is Set) {
      return value.fold<int>(0, (hash, element) => hash + element.hashCode);
    }
    if (value is Map) {
      return value.entries.fold<int>(
        0,
        (hash, entry) => hash + Object.hash(entry.key, entry.value),
      );
    }
    return value.hashCode;
  }

  static ZorphyBoundaryResult<BoundaryViolationFailure> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_message = raw['message'];
    String? _message;
    _message = _boundaryAs<String>(raw_message, '/message', violations);
    final Object? raw_traceId = raw['traceId'];
    String? _traceId;
    if (raw_traceId != null) {
      _traceId = _boundaryAs<String>(raw_traceId, '/traceId', violations);
    }
    final Object? raw_isRetryable = raw['isRetryable'];
    bool? _isRetryable;
    _isRetryable = _boundaryAs<bool>(
      raw_isRetryable,
      '/isRetryable',
      violations,
    );
    final Object? raw_code = raw['code'];
    String? _code;
    if (raw_code != null) {
      _code = _boundaryAs<String>(raw_code, '/code', violations);
    }
    final Object? raw_violations = raw['violations'];
    List<FieldViolation>? _violations;
    final list_violations = _boundaryList(
      raw_violations,
      '/violations',
      violations,
    );
    if (list_violations != null) {
      final decoded_violations = <FieldViolation>[];
      for (var i = 0; i < list_violations.length; i++) {
        final path_violations = '/violations' + '[$i]';
        final element_violations = _boundaryAs<FieldViolation>(
          list_violations[i],
          path_violations,
          violations,
        );
        if (element_violations != null) {
          decoded_violations.add(element_violations);
        }
      }
      _violations = decoded_violations;
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<BoundaryViolationFailure>(
        targetType: 'BoundaryViolationFailure',
        violations: violations,
      );
    }
    return BoundaryOk<BoundaryViolationFailure>(
      BoundaryViolationFailure.fromTrusted(
        message: _message!,
        traceId: _traceId,
        isRetryable: _isRetryable!,
        code: _code,
        violations: _violations!,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{'kind': 'boundary_violation_failure'};
    map['message'] = this.message;
    final _traceId = this.traceId;
    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    map['isRetryable'] = this.isRetryable;
    final _code = this.code;
    if (_code != null) {
      map['code'] = _code;
    }
    map['violations'] = this.violations;
    return map;
  }

  static ZorphyBoundaryResult<BoundaryViolationFailure> fromJson(
    Map<String, dynamic> json,
  ) {
    return BoundaryViolationFailure.fromWire(json);
  }

  Map<String, dynamic> toJson() {
    return toWire();
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [BoundaryViolationFailure].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<BoundaryViolationFailure, Object?>? resolvePath(
    String pointer,
  ) {
    return switch (pointer) {
      '/message' => ZorphyLens<BoundaryViolationFailure, Object?>(
        path: '/message',
        get: (root) => root.message,
        set: (root, value) => root.copyWith(message: value as String),
      ),
      '/traceId' => ZorphyLens<BoundaryViolationFailure, Object?>(
        path: '/traceId',
        get: (root) => root.traceId,
        set: (root, value) => root.copyWith(traceId: value as String?),
      ),
      '/isRetryable' => ZorphyLens<BoundaryViolationFailure, Object?>(
        path: '/isRetryable',
        get: (root) => root.isRetryable,
        set: (root, value) => root.copyWith(isRetryable: value as bool),
      ),
      '/code' => ZorphyLens<BoundaryViolationFailure, Object?>(
        path: '/code',
        get: (root) => root.code,
        set: (root, value) => root.copyWith(code: value as String?),
      ),
      '/violations' => ZorphyLens<BoundaryViolationFailure, Object?>(
        path: '/violations',
        get: (root) => root.violations,
        set: (root, value) =>
            root.copyWith(violations: value as List<FieldViolation>),
      ),
      _ => null,
    };
  }
}

final class PolicyDeniedFailure extends AppFailure implements ZorphyValueBase {
  const PolicyDeniedFailure.fromTrusted({
    required this.message,
    this.traceId,
    required this.isRetryable,
    this.code,
    required this.reason,
  });

  @override
  final String message;

  @override
  final String? traceId;

  @override
  final bool isRetryable;

  @override
  final String? code;

  final String reason;

  static const PolicyDeniedFailureLenses lenses = PolicyDeniedFailureLenses();

  PolicyDeniedFailure copyWith({
    String? message,
    Object? traceId = _sentinel,
    bool? isRetryable,
    Object? code = _sentinel,
    String? reason,
  }) {
    return PolicyDeniedFailure.fromTrusted(
      message: message ?? this.message,
      traceId: identical(traceId, _sentinel)
          ? this.traceId
          : traceId as String?,
      isRetryable: isRetryable ?? this.isRetryable,
      code: identical(code, _sentinel) ? this.code : code as String?,
      reason: reason ?? this.reason,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PolicyDeniedFailure &&
        this.message == other.message &&
        this.traceId == other.traceId &&
        this.isRetryable == other.isRetryable &&
        this.code == other.code &&
        this.reason == other.reason;
  }

  @override
  int get hashCode =>
      Object.hashAll([message, traceId, isRetryable, code, reason]);

  @override
  String toString() =>
      'PolicyDeniedFailure(message: $message, traceId: $traceId, isRetryable: $isRetryable, code: $code, reason: $reason)';

  static ZorphyBoundaryResult<PolicyDeniedFailure> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_message = raw['message'];
    String? _message;
    _message = _boundaryAs<String>(raw_message, '/message', violations);
    final Object? raw_traceId = raw['traceId'];
    String? _traceId;
    if (raw_traceId != null) {
      _traceId = _boundaryAs<String>(raw_traceId, '/traceId', violations);
    }
    final Object? raw_isRetryable = raw['isRetryable'];
    bool? _isRetryable;
    _isRetryable = _boundaryAs<bool>(
      raw_isRetryable,
      '/isRetryable',
      violations,
    );
    final Object? raw_code = raw['code'];
    String? _code;
    if (raw_code != null) {
      _code = _boundaryAs<String>(raw_code, '/code', violations);
    }
    final Object? raw_reason = raw['reason'];
    String? _reason;
    _reason = _boundaryAs<String>(raw_reason, '/reason', violations);
    if (violations.isNotEmpty) {
      return BoundaryErr<PolicyDeniedFailure>(
        targetType: 'PolicyDeniedFailure',
        violations: violations,
      );
    }
    return BoundaryOk<PolicyDeniedFailure>(
      PolicyDeniedFailure.fromTrusted(
        message: _message!,
        traceId: _traceId,
        isRetryable: _isRetryable!,
        code: _code,
        reason: _reason!,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{'kind': 'policy_denied_failure'};
    map['message'] = this.message;
    final _traceId = this.traceId;
    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    map['isRetryable'] = this.isRetryable;
    final _code = this.code;
    if (_code != null) {
      map['code'] = _code;
    }
    map['reason'] = this.reason;
    return map;
  }

  static ZorphyBoundaryResult<PolicyDeniedFailure> fromJson(
    Map<String, dynamic> json,
  ) {
    return PolicyDeniedFailure.fromWire(json);
  }

  Map<String, dynamic> toJson() {
    return toWire();
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [PolicyDeniedFailure].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<PolicyDeniedFailure, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/message' => ZorphyLens<PolicyDeniedFailure, Object?>(
        path: '/message',
        get: (root) => root.message,
        set: (root, value) => root.copyWith(message: value as String),
      ),
      '/traceId' => ZorphyLens<PolicyDeniedFailure, Object?>(
        path: '/traceId',
        get: (root) => root.traceId,
        set: (root, value) => root.copyWith(traceId: value as String?),
      ),
      '/isRetryable' => ZorphyLens<PolicyDeniedFailure, Object?>(
        path: '/isRetryable',
        get: (root) => root.isRetryable,
        set: (root, value) => root.copyWith(isRetryable: value as bool),
      ),
      '/code' => ZorphyLens<PolicyDeniedFailure, Object?>(
        path: '/code',
        get: (root) => root.code,
        set: (root, value) => root.copyWith(code: value as String?),
      ),
      '/reason' => ZorphyLens<PolicyDeniedFailure, Object?>(
        path: '/reason',
        get: (root) => root.reason,
        set: (root, value) => root.copyWith(reason: value as String),
      ),
      _ => null,
    };
  }
}

final class NotFoundFailure extends AppFailure implements ZorphyValueBase {
  const NotFoundFailure.fromTrusted({
    required this.message,
    this.traceId,
    required this.isRetryable,
    this.code,
    this.resourceType,
    this.resourceId,
  });

  @override
  final String message;

  @override
  final String? traceId;

  @override
  final bool isRetryable;

  @override
  final String? code;

  final String? resourceType;

  final String? resourceId;

  static const NotFoundFailureLenses lenses = NotFoundFailureLenses();

  NotFoundFailure copyWith({
    String? message,
    Object? traceId = _sentinel,
    bool? isRetryable,
    Object? code = _sentinel,
    Object? resourceType = _sentinel,
    Object? resourceId = _sentinel,
  }) {
    return NotFoundFailure.fromTrusted(
      message: message ?? this.message,
      traceId: identical(traceId, _sentinel)
          ? this.traceId
          : traceId as String?,
      isRetryable: isRetryable ?? this.isRetryable,
      code: identical(code, _sentinel) ? this.code : code as String?,
      resourceType: identical(resourceType, _sentinel)
          ? this.resourceType
          : resourceType as String?,
      resourceId: identical(resourceId, _sentinel)
          ? this.resourceId
          : resourceId as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotFoundFailure &&
        this.message == other.message &&
        this.traceId == other.traceId &&
        this.isRetryable == other.isRetryable &&
        this.code == other.code &&
        this.resourceType == other.resourceType &&
        this.resourceId == other.resourceId;
  }

  @override
  int get hashCode => Object.hashAll([
    message,
    traceId,
    isRetryable,
    code,
    resourceType,
    resourceId,
  ]);

  @override
  String toString() =>
      'NotFoundFailure(message: $message, traceId: $traceId, isRetryable: $isRetryable, code: $code, resourceType: $resourceType, resourceId: $resourceId)';

  static ZorphyBoundaryResult<NotFoundFailure> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_message = raw['message'];
    String? _message;
    _message = _boundaryAs<String>(raw_message, '/message', violations);
    final Object? raw_traceId = raw['traceId'];
    String? _traceId;
    if (raw_traceId != null) {
      _traceId = _boundaryAs<String>(raw_traceId, '/traceId', violations);
    }
    final Object? raw_isRetryable = raw['isRetryable'];
    bool? _isRetryable;
    _isRetryable = _boundaryAs<bool>(
      raw_isRetryable,
      '/isRetryable',
      violations,
    );
    final Object? raw_code = raw['code'];
    String? _code;
    if (raw_code != null) {
      _code = _boundaryAs<String>(raw_code, '/code', violations);
    }
    final Object? raw_resourceType = raw['resourceType'];
    String? _resourceType;
    if (raw_resourceType != null) {
      _resourceType = _boundaryAs<String>(
        raw_resourceType,
        '/resourceType',
        violations,
      );
    }
    final Object? raw_resourceId = raw['resourceId'];
    String? _resourceId;
    if (raw_resourceId != null) {
      _resourceId = _boundaryAs<String>(
        raw_resourceId,
        '/resourceId',
        violations,
      );
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<NotFoundFailure>(
        targetType: 'NotFoundFailure',
        violations: violations,
      );
    }
    return BoundaryOk<NotFoundFailure>(
      NotFoundFailure.fromTrusted(
        message: _message!,
        traceId: _traceId,
        isRetryable: _isRetryable!,
        code: _code,
        resourceType: _resourceType,
        resourceId: _resourceId,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{'kind': 'not_found_failure'};
    map['message'] = this.message;
    final _traceId = this.traceId;
    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    map['isRetryable'] = this.isRetryable;
    final _code = this.code;
    if (_code != null) {
      map['code'] = _code;
    }
    final _resourceType = this.resourceType;
    if (_resourceType != null) {
      map['resourceType'] = _resourceType;
    }
    final _resourceId = this.resourceId;
    if (_resourceId != null) {
      map['resourceId'] = _resourceId;
    }
    return map;
  }

  static ZorphyBoundaryResult<NotFoundFailure> fromJson(
    Map<String, dynamic> json,
  ) {
    return NotFoundFailure.fromWire(json);
  }

  Map<String, dynamic> toJson() {
    return toWire();
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [NotFoundFailure].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<NotFoundFailure, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/message' => ZorphyLens<NotFoundFailure, Object?>(
        path: '/message',
        get: (root) => root.message,
        set: (root, value) => root.copyWith(message: value as String),
      ),
      '/traceId' => ZorphyLens<NotFoundFailure, Object?>(
        path: '/traceId',
        get: (root) => root.traceId,
        set: (root, value) => root.copyWith(traceId: value as String?),
      ),
      '/isRetryable' => ZorphyLens<NotFoundFailure, Object?>(
        path: '/isRetryable',
        get: (root) => root.isRetryable,
        set: (root, value) => root.copyWith(isRetryable: value as bool),
      ),
      '/code' => ZorphyLens<NotFoundFailure, Object?>(
        path: '/code',
        get: (root) => root.code,
        set: (root, value) => root.copyWith(code: value as String?),
      ),
      '/resourceType' => ZorphyLens<NotFoundFailure, Object?>(
        path: '/resourceType',
        get: (root) => root.resourceType,
        set: (root, value) => root.copyWith(resourceType: value as String?),
      ),
      '/resourceId' => ZorphyLens<NotFoundFailure, Object?>(
        path: '/resourceId',
        get: (root) => root.resourceId,
        set: (root, value) => root.copyWith(resourceId: value as String?),
      ),
      _ => null,
    };
  }
}

final class ConflictFailure extends AppFailure implements ZorphyValueBase {
  ConflictFailure.fromTrusted({
    required this.message,
    this.traceId,
    required this.isRetryable,
    this.code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) : localPatchWire = localPatchWire == null
           ? null
           : Map<String, Object?>.of(localPatchWire),
       remotePatchWire = remotePatchWire == null
           ? null
           : Map<String, Object?>.of(remotePatchWire);

  @override
  final String message;

  @override
  final String? traceId;

  @override
  final bool isRetryable;

  @override
  final String? code;

  final Map<String, Object?>? localPatchWire;

  final Map<String, Object?>? remotePatchWire;

  static const ConflictFailureLenses lenses = ConflictFailureLenses();

  ConflictFailure copyWith({
    String? message,
    Object? traceId = _sentinel,
    bool? isRetryable,
    Object? code = _sentinel,
    Object? localPatchWire = _sentinel,
    Object? remotePatchWire = _sentinel,
  }) {
    return ConflictFailure.fromTrusted(
      message: message ?? this.message,
      traceId: identical(traceId, _sentinel)
          ? this.traceId
          : traceId as String?,
      isRetryable: isRetryable ?? this.isRetryable,
      code: identical(code, _sentinel) ? this.code : code as String?,
      localPatchWire: identical(localPatchWire, _sentinel)
          ? this.localPatchWire
          : localPatchWire as Map<String, Object?>?,
      remotePatchWire: identical(remotePatchWire, _sentinel)
          ? this.remotePatchWire
          : remotePatchWire as Map<String, Object?>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConflictFailure &&
        this.message == other.message &&
        this.traceId == other.traceId &&
        this.isRetryable == other.isRetryable &&
        this.code == other.code &&
        ConflictFailure._zorphyCollectionEquals(
          this.localPatchWire,
          other.localPatchWire,
        ) &&
        ConflictFailure._zorphyCollectionEquals(
          this.remotePatchWire,
          other.remotePatchWire,
        );
  }

  @override
  int get hashCode => Object.hashAll([
    message,
    traceId,
    isRetryable,
    code,
    ConflictFailure._zorphyCollectionHash(localPatchWire),
    ConflictFailure._zorphyCollectionHash(remotePatchWire),
  ]);

  @override
  String toString() =>
      'ConflictFailure(message: $message, traceId: $traceId, isRetryable: $isRetryable, code: $code, localPatchWire: $localPatchWire, remotePatchWire: $remotePatchWire)';

  static bool _zorphyCollectionEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    if (a is Set && b is Set) {
      if (a.length != b.length) return false;
      return a.every(b.contains);
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  static int _zorphyCollectionHash(Object? value) {
    if (value is List) return Object.hashAll(value);
    if (value is Set) {
      return value.fold<int>(0, (hash, element) => hash + element.hashCode);
    }
    if (value is Map) {
      return value.entries.fold<int>(
        0,
        (hash, entry) => hash + Object.hash(entry.key, entry.value),
      );
    }
    return value.hashCode;
  }

  static ZorphyBoundaryResult<ConflictFailure> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_message = raw['message'];
    String? _message;
    _message = _boundaryAs<String>(raw_message, '/message', violations);
    final Object? raw_traceId = raw['traceId'];
    String? _traceId;
    if (raw_traceId != null) {
      _traceId = _boundaryAs<String>(raw_traceId, '/traceId', violations);
    }
    final Object? raw_isRetryable = raw['isRetryable'];
    bool? _isRetryable;
    _isRetryable = _boundaryAs<bool>(
      raw_isRetryable,
      '/isRetryable',
      violations,
    );
    final Object? raw_code = raw['code'];
    String? _code;
    if (raw_code != null) {
      _code = _boundaryAs<String>(raw_code, '/code', violations);
    }
    final Object? raw_localPatchWire = raw['localPatchWire'];
    Map<String, Object?>? _localPatchWire;
    if (raw_localPatchWire != null) {
      final map_localPatchWire = _boundaryObject(
        raw_localPatchWire,
        '/localPatchWire',
        violations,
      );
      if (map_localPatchWire != null) {
        final decoded_localPatchWire = <String, Object?>{};
        for (final entry in map_localPatchWire.entries) {
          final path_localPatchWire = '/localPatchWire' + '/' + entry.key;
          if (map_localPatchWire[entry.key] == null) {
            decoded_localPatchWire[entry.key] = null;
          } else {
            final element_localPatchWire = _boundaryAs<Object?>(
              map_localPatchWire[entry.key],
              path_localPatchWire,
              violations,
            );
            if (element_localPatchWire != null) {
              decoded_localPatchWire[entry.key] = element_localPatchWire;
            }
          }
        }
        _localPatchWire = decoded_localPatchWire;
      }
    }
    final Object? raw_remotePatchWire = raw['remotePatchWire'];
    Map<String, Object?>? _remotePatchWire;
    if (raw_remotePatchWire != null) {
      final map_remotePatchWire = _boundaryObject(
        raw_remotePatchWire,
        '/remotePatchWire',
        violations,
      );
      if (map_remotePatchWire != null) {
        final decoded_remotePatchWire = <String, Object?>{};
        for (final entry in map_remotePatchWire.entries) {
          final path_remotePatchWire = '/remotePatchWire' + '/' + entry.key;
          if (map_remotePatchWire[entry.key] == null) {
            decoded_remotePatchWire[entry.key] = null;
          } else {
            final element_remotePatchWire = _boundaryAs<Object?>(
              map_remotePatchWire[entry.key],
              path_remotePatchWire,
              violations,
            );
            if (element_remotePatchWire != null) {
              decoded_remotePatchWire[entry.key] = element_remotePatchWire;
            }
          }
        }
        _remotePatchWire = decoded_remotePatchWire;
      }
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<ConflictFailure>(
        targetType: 'ConflictFailure',
        violations: violations,
      );
    }
    return BoundaryOk<ConflictFailure>(
      ConflictFailure.fromTrusted(
        message: _message!,
        traceId: _traceId,
        isRetryable: _isRetryable!,
        code: _code,
        localPatchWire: _localPatchWire,
        remotePatchWire: _remotePatchWire,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{'kind': 'conflict_failure'};
    map['message'] = this.message;
    final _traceId = this.traceId;
    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    map['isRetryable'] = this.isRetryable;
    final _code = this.code;
    if (_code != null) {
      map['code'] = _code;
    }
    final _localPatchWire = this.localPatchWire;
    if (_localPatchWire != null) {
      map['localPatchWire'] = _localPatchWire;
    }
    final _remotePatchWire = this.remotePatchWire;
    if (_remotePatchWire != null) {
      map['remotePatchWire'] = _remotePatchWire;
    }
    return map;
  }

  static ZorphyBoundaryResult<ConflictFailure> fromJson(
    Map<String, dynamic> json,
  ) {
    return ConflictFailure.fromWire(json);
  }

  Map<String, dynamic> toJson() {
    return toWire();
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [ConflictFailure].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<ConflictFailure, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/message' => ZorphyLens<ConflictFailure, Object?>(
        path: '/message',
        get: (root) => root.message,
        set: (root, value) => root.copyWith(message: value as String),
      ),
      '/traceId' => ZorphyLens<ConflictFailure, Object?>(
        path: '/traceId',
        get: (root) => root.traceId,
        set: (root, value) => root.copyWith(traceId: value as String?),
      ),
      '/isRetryable' => ZorphyLens<ConflictFailure, Object?>(
        path: '/isRetryable',
        get: (root) => root.isRetryable,
        set: (root, value) => root.copyWith(isRetryable: value as bool),
      ),
      '/code' => ZorphyLens<ConflictFailure, Object?>(
        path: '/code',
        get: (root) => root.code,
        set: (root, value) => root.copyWith(code: value as String?),
      ),
      '/localPatchWire' => ZorphyLens<ConflictFailure, Object?>(
        path: '/localPatchWire',
        get: (root) => root.localPatchWire,
        set: (root, value) =>
            root.copyWith(localPatchWire: value as Map<String, Object?>?),
      ),
      '/remotePatchWire' => ZorphyLens<ConflictFailure, Object?>(
        path: '/remotePatchWire',
        get: (root) => root.remotePatchWire,
        set: (root, value) =>
            root.copyWith(remotePatchWire: value as Map<String, Object?>?),
      ),
      _ => null,
    };
  }
}

final class CancelledFailure extends AppFailure implements ZorphyValueBase {
  const CancelledFailure.fromTrusted({
    required this.message,
    this.traceId,
    required this.isRetryable,
    this.code,
  });

  @override
  final String message;

  @override
  final String? traceId;

  @override
  final bool isRetryable;

  @override
  final String? code;

  static const CancelledFailureLenses lenses = CancelledFailureLenses();

  CancelledFailure copyWith({
    String? message,
    Object? traceId = _sentinel,
    bool? isRetryable,
    Object? code = _sentinel,
  }) {
    return CancelledFailure.fromTrusted(
      message: message ?? this.message,
      traceId: identical(traceId, _sentinel)
          ? this.traceId
          : traceId as String?,
      isRetryable: isRetryable ?? this.isRetryable,
      code: identical(code, _sentinel) ? this.code : code as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CancelledFailure &&
        this.message == other.message &&
        this.traceId == other.traceId &&
        this.isRetryable == other.isRetryable &&
        this.code == other.code;
  }

  @override
  int get hashCode => Object.hashAll([message, traceId, isRetryable, code]);

  @override
  String toString() =>
      'CancelledFailure(message: $message, traceId: $traceId, isRetryable: $isRetryable, code: $code)';

  static ZorphyBoundaryResult<CancelledFailure> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_message = raw['message'];
    String? _message;
    _message = _boundaryAs<String>(raw_message, '/message', violations);
    final Object? raw_traceId = raw['traceId'];
    String? _traceId;
    if (raw_traceId != null) {
      _traceId = _boundaryAs<String>(raw_traceId, '/traceId', violations);
    }
    final Object? raw_isRetryable = raw['isRetryable'];
    bool? _isRetryable;
    _isRetryable = _boundaryAs<bool>(
      raw_isRetryable,
      '/isRetryable',
      violations,
    );
    final Object? raw_code = raw['code'];
    String? _code;
    if (raw_code != null) {
      _code = _boundaryAs<String>(raw_code, '/code', violations);
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<CancelledFailure>(
        targetType: 'CancelledFailure',
        violations: violations,
      );
    }
    return BoundaryOk<CancelledFailure>(
      CancelledFailure.fromTrusted(
        message: _message!,
        traceId: _traceId,
        isRetryable: _isRetryable!,
        code: _code,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{'kind': 'cancelled_failure'};
    map['message'] = this.message;
    final _traceId = this.traceId;
    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    map['isRetryable'] = this.isRetryable;
    final _code = this.code;
    if (_code != null) {
      map['code'] = _code;
    }
    return map;
  }

  static ZorphyBoundaryResult<CancelledFailure> fromJson(
    Map<String, dynamic> json,
  ) {
    return CancelledFailure.fromWire(json);
  }

  Map<String, dynamic> toJson() {
    return toWire();
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [CancelledFailure].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<CancelledFailure, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/message' => ZorphyLens<CancelledFailure, Object?>(
        path: '/message',
        get: (root) => root.message,
        set: (root, value) => root.copyWith(message: value as String),
      ),
      '/traceId' => ZorphyLens<CancelledFailure, Object?>(
        path: '/traceId',
        get: (root) => root.traceId,
        set: (root, value) => root.copyWith(traceId: value as String?),
      ),
      '/isRetryable' => ZorphyLens<CancelledFailure, Object?>(
        path: '/isRetryable',
        get: (root) => root.isRetryable,
        set: (root, value) => root.copyWith(isRetryable: value as bool),
      ),
      '/code' => ZorphyLens<CancelledFailure, Object?>(
        path: '/code',
        get: (root) => root.code,
        set: (root, value) => root.copyWith(code: value as String?),
      ),
      _ => null,
    };
  }
}

final class InterruptedFailure extends AppFailure implements ZorphyValueBase {
  const InterruptedFailure.fromTrusted({
    required this.message,
    this.traceId,
    required this.isRetryable,
    this.code,
    this.intentDigest,
  });

  @override
  final String message;

  @override
  final String? traceId;

  @override
  final bool isRetryable;

  @override
  final String? code;

  final String? intentDigest;

  static const InterruptedFailureLenses lenses = InterruptedFailureLenses();

  InterruptedFailure copyWith({
    String? message,
    Object? traceId = _sentinel,
    bool? isRetryable,
    Object? code = _sentinel,
    Object? intentDigest = _sentinel,
  }) {
    return InterruptedFailure.fromTrusted(
      message: message ?? this.message,
      traceId: identical(traceId, _sentinel)
          ? this.traceId
          : traceId as String?,
      isRetryable: isRetryable ?? this.isRetryable,
      code: identical(code, _sentinel) ? this.code : code as String?,
      intentDigest: identical(intentDigest, _sentinel)
          ? this.intentDigest
          : intentDigest as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InterruptedFailure &&
        this.message == other.message &&
        this.traceId == other.traceId &&
        this.isRetryable == other.isRetryable &&
        this.code == other.code &&
        this.intentDigest == other.intentDigest;
  }

  @override
  int get hashCode =>
      Object.hashAll([message, traceId, isRetryable, code, intentDigest]);

  @override
  String toString() =>
      'InterruptedFailure(message: $message, traceId: $traceId, isRetryable: $isRetryable, code: $code, intentDigest: $intentDigest)';

  static ZorphyBoundaryResult<InterruptedFailure> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_message = raw['message'];
    String? _message;
    _message = _boundaryAs<String>(raw_message, '/message', violations);
    final Object? raw_traceId = raw['traceId'];
    String? _traceId;
    if (raw_traceId != null) {
      _traceId = _boundaryAs<String>(raw_traceId, '/traceId', violations);
    }
    final Object? raw_isRetryable = raw['isRetryable'];
    bool? _isRetryable;
    _isRetryable = _boundaryAs<bool>(
      raw_isRetryable,
      '/isRetryable',
      violations,
    );
    final Object? raw_code = raw['code'];
    String? _code;
    if (raw_code != null) {
      _code = _boundaryAs<String>(raw_code, '/code', violations);
    }
    final Object? raw_intentDigest = raw['intentDigest'];
    String? _intentDigest;
    if (raw_intentDigest != null) {
      _intentDigest = _boundaryAs<String>(
        raw_intentDigest,
        '/intentDigest',
        violations,
      );
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<InterruptedFailure>(
        targetType: 'InterruptedFailure',
        violations: violations,
      );
    }
    return BoundaryOk<InterruptedFailure>(
      InterruptedFailure.fromTrusted(
        message: _message!,
        traceId: _traceId,
        isRetryable: _isRetryable!,
        code: _code,
        intentDigest: _intentDigest,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{'kind': 'interrupted_failure'};
    map['message'] = this.message;
    final _traceId = this.traceId;
    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    map['isRetryable'] = this.isRetryable;
    final _code = this.code;
    if (_code != null) {
      map['code'] = _code;
    }
    final _intentDigest = this.intentDigest;
    if (_intentDigest != null) {
      map['intentDigest'] = _intentDigest;
    }
    return map;
  }

  static ZorphyBoundaryResult<InterruptedFailure> fromJson(
    Map<String, dynamic> json,
  ) {
    return InterruptedFailure.fromWire(json);
  }

  Map<String, dynamic> toJson() {
    return toWire();
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [InterruptedFailure].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<InterruptedFailure, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/message' => ZorphyLens<InterruptedFailure, Object?>(
        path: '/message',
        get: (root) => root.message,
        set: (root, value) => root.copyWith(message: value as String),
      ),
      '/traceId' => ZorphyLens<InterruptedFailure, Object?>(
        path: '/traceId',
        get: (root) => root.traceId,
        set: (root, value) => root.copyWith(traceId: value as String?),
      ),
      '/isRetryable' => ZorphyLens<InterruptedFailure, Object?>(
        path: '/isRetryable',
        get: (root) => root.isRetryable,
        set: (root, value) => root.copyWith(isRetryable: value as bool),
      ),
      '/code' => ZorphyLens<InterruptedFailure, Object?>(
        path: '/code',
        get: (root) => root.code,
        set: (root, value) => root.copyWith(code: value as String?),
      ),
      '/intentDigest' => ZorphyLens<InterruptedFailure, Object?>(
        path: '/intentDigest',
        get: (root) => root.intentDigest,
        set: (root, value) => root.copyWith(intentDigest: value as String?),
      ),
      _ => null,
    };
  }
}

final class StorageFailure extends AppFailure implements ZorphyValueBase {
  const StorageFailure.fromTrusted({
    required this.message,
    this.traceId,
    required this.isRetryable,
    this.code,
    required this.layer,
  });

  @override
  final String message;

  @override
  final String? traceId;

  @override
  final bool isRetryable;

  @override
  final String? code;

  final String layer;

  static const StorageFailureLenses lenses = StorageFailureLenses();

  StorageFailure copyWith({
    String? message,
    Object? traceId = _sentinel,
    bool? isRetryable,
    Object? code = _sentinel,
    String? layer,
  }) {
    return StorageFailure.fromTrusted(
      message: message ?? this.message,
      traceId: identical(traceId, _sentinel)
          ? this.traceId
          : traceId as String?,
      isRetryable: isRetryable ?? this.isRetryable,
      code: identical(code, _sentinel) ? this.code : code as String?,
      layer: layer ?? this.layer,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StorageFailure &&
        this.message == other.message &&
        this.traceId == other.traceId &&
        this.isRetryable == other.isRetryable &&
        this.code == other.code &&
        this.layer == other.layer;
  }

  @override
  int get hashCode =>
      Object.hashAll([message, traceId, isRetryable, code, layer]);

  @override
  String toString() =>
      'StorageFailure(message: $message, traceId: $traceId, isRetryable: $isRetryable, code: $code, layer: $layer)';

  static ZorphyBoundaryResult<StorageFailure> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_message = raw['message'];
    String? _message;
    _message = _boundaryAs<String>(raw_message, '/message', violations);
    final Object? raw_traceId = raw['traceId'];
    String? _traceId;
    if (raw_traceId != null) {
      _traceId = _boundaryAs<String>(raw_traceId, '/traceId', violations);
    }
    final Object? raw_isRetryable = raw['isRetryable'];
    bool? _isRetryable;
    _isRetryable = _boundaryAs<bool>(
      raw_isRetryable,
      '/isRetryable',
      violations,
    );
    final Object? raw_code = raw['code'];
    String? _code;
    if (raw_code != null) {
      _code = _boundaryAs<String>(raw_code, '/code', violations);
    }
    final Object? raw_layer = raw['layer'];
    String? _layer;
    _layer = _boundaryAs<String>(raw_layer, '/layer', violations);
    if (violations.isNotEmpty) {
      return BoundaryErr<StorageFailure>(
        targetType: 'StorageFailure',
        violations: violations,
      );
    }
    return BoundaryOk<StorageFailure>(
      StorageFailure.fromTrusted(
        message: _message!,
        traceId: _traceId,
        isRetryable: _isRetryable!,
        code: _code,
        layer: _layer!,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{'kind': 'storage_failure'};
    map['message'] = this.message;
    final _traceId = this.traceId;
    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    map['isRetryable'] = this.isRetryable;
    final _code = this.code;
    if (_code != null) {
      map['code'] = _code;
    }
    map['layer'] = this.layer;
    return map;
  }

  static ZorphyBoundaryResult<StorageFailure> fromJson(
    Map<String, dynamic> json,
  ) {
    return StorageFailure.fromWire(json);
  }

  Map<String, dynamic> toJson() {
    return toWire();
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [StorageFailure].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<StorageFailure, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/message' => ZorphyLens<StorageFailure, Object?>(
        path: '/message',
        get: (root) => root.message,
        set: (root, value) => root.copyWith(message: value as String),
      ),
      '/traceId' => ZorphyLens<StorageFailure, Object?>(
        path: '/traceId',
        get: (root) => root.traceId,
        set: (root, value) => root.copyWith(traceId: value as String?),
      ),
      '/isRetryable' => ZorphyLens<StorageFailure, Object?>(
        path: '/isRetryable',
        get: (root) => root.isRetryable,
        set: (root, value) => root.copyWith(isRetryable: value as bool),
      ),
      '/code' => ZorphyLens<StorageFailure, Object?>(
        path: '/code',
        get: (root) => root.code,
        set: (root, value) => root.copyWith(code: value as String?),
      ),
      '/layer' => ZorphyLens<StorageFailure, Object?>(
        path: '/layer',
        get: (root) => root.layer,
        set: (root, value) => root.copyWith(layer: value as String),
      ),
      _ => null,
    };
  }
}

final class UnexpectedFailure extends AppFailure implements ZorphyValueBase {
  const UnexpectedFailure.fromTrusted({
    required this.message,
    this.traceId,
    required this.isRetryable,
    this.code,
    this.cause,
    this.stackTrace,
  });

  @override
  final String message;

  @override
  final String? traceId;

  @override
  final bool isRetryable;

  @override
  final String? code;

  final String? cause;

  final String? stackTrace;

  static const UnexpectedFailureLenses lenses = UnexpectedFailureLenses();

  UnexpectedFailure copyWith({
    String? message,
    Object? traceId = _sentinel,
    bool? isRetryable,
    Object? code = _sentinel,
    Object? cause = _sentinel,
    Object? stackTrace = _sentinel,
  }) {
    return UnexpectedFailure.fromTrusted(
      message: message ?? this.message,
      traceId: identical(traceId, _sentinel)
          ? this.traceId
          : traceId as String?,
      isRetryable: isRetryable ?? this.isRetryable,
      code: identical(code, _sentinel) ? this.code : code as String?,
      cause: identical(cause, _sentinel) ? this.cause : cause as String?,
      stackTrace: identical(stackTrace, _sentinel)
          ? this.stackTrace
          : stackTrace as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnexpectedFailure &&
        this.message == other.message &&
        this.traceId == other.traceId &&
        this.isRetryable == other.isRetryable &&
        this.code == other.code &&
        this.cause == other.cause &&
        this.stackTrace == other.stackTrace;
  }

  @override
  int get hashCode =>
      Object.hashAll([message, traceId, isRetryable, code, cause, stackTrace]);

  @override
  String toString() =>
      'UnexpectedFailure(message: $message, traceId: $traceId, isRetryable: $isRetryable, code: $code, cause: $cause, stackTrace: $stackTrace)';

  static ZorphyBoundaryResult<UnexpectedFailure> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_message = raw['message'];
    String? _message;
    _message = _boundaryAs<String>(raw_message, '/message', violations);
    final Object? raw_traceId = raw['traceId'];
    String? _traceId;
    if (raw_traceId != null) {
      _traceId = _boundaryAs<String>(raw_traceId, '/traceId', violations);
    }
    final Object? raw_isRetryable = raw['isRetryable'];
    bool? _isRetryable;
    _isRetryable = _boundaryAs<bool>(
      raw_isRetryable,
      '/isRetryable',
      violations,
    );
    final Object? raw_code = raw['code'];
    String? _code;
    if (raw_code != null) {
      _code = _boundaryAs<String>(raw_code, '/code', violations);
    }
    final Object? raw_cause = raw['cause'];
    String? _cause;
    if (raw_cause != null) {
      _cause = _boundaryAs<String>(raw_cause, '/cause', violations);
    }
    final Object? raw_stackTrace = raw['stackTrace'];
    String? _stackTrace;
    if (raw_stackTrace != null) {
      _stackTrace = _boundaryAs<String>(
        raw_stackTrace,
        '/stackTrace',
        violations,
      );
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<UnexpectedFailure>(
        targetType: 'UnexpectedFailure',
        violations: violations,
      );
    }
    return BoundaryOk<UnexpectedFailure>(
      UnexpectedFailure.fromTrusted(
        message: _message!,
        traceId: _traceId,
        isRetryable: _isRetryable!,
        code: _code,
        cause: _cause,
        stackTrace: _stackTrace,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{'kind': 'unexpected_failure'};
    map['message'] = this.message;
    final _traceId = this.traceId;
    if (_traceId != null) {
      map['traceId'] = _traceId;
    }
    map['isRetryable'] = this.isRetryable;
    final _code = this.code;
    if (_code != null) {
      map['code'] = _code;
    }
    final _cause = this.cause;
    if (_cause != null) {
      map['cause'] = _cause;
    }
    final _stackTrace = this.stackTrace;
    if (_stackTrace != null) {
      map['stackTrace'] = _stackTrace;
    }
    return map;
  }

  static ZorphyBoundaryResult<UnexpectedFailure> fromJson(
    Map<String, dynamic> json,
  ) {
    return UnexpectedFailure.fromWire(json);
  }

  Map<String, dynamic> toJson() {
    return toWire();
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [UnexpectedFailure].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<UnexpectedFailure, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/message' => ZorphyLens<UnexpectedFailure, Object?>(
        path: '/message',
        get: (root) => root.message,
        set: (root, value) => root.copyWith(message: value as String),
      ),
      '/traceId' => ZorphyLens<UnexpectedFailure, Object?>(
        path: '/traceId',
        get: (root) => root.traceId,
        set: (root, value) => root.copyWith(traceId: value as String?),
      ),
      '/isRetryable' => ZorphyLens<UnexpectedFailure, Object?>(
        path: '/isRetryable',
        get: (root) => root.isRetryable,
        set: (root, value) => root.copyWith(isRetryable: value as bool),
      ),
      '/code' => ZorphyLens<UnexpectedFailure, Object?>(
        path: '/code',
        get: (root) => root.code,
        set: (root, value) => root.copyWith(code: value as String?),
      ),
      '/cause' => ZorphyLens<UnexpectedFailure, Object?>(
        path: '/cause',
        get: (root) => root.cause,
        set: (root, value) => root.copyWith(cause: value as String?),
      ),
      '/stackTrace' => ZorphyLens<UnexpectedFailure, Object?>(
        path: '/stackTrace',
        get: (root) => root.stackTrace,
        set: (root, value) => root.copyWith(stackTrace: value as String?),
      ),
      _ => null,
    };
  }
}

class AppFailureMockData {
  AppFailureMockData._();

  static AppFailure single({int seed = 0}) {
    return switch (seed % 10) {
      0 => NetworkFailureMockData.single(seed: seed),
      1 => TimeoutFailureMockData.single(seed: seed),
      2 => BoundaryViolationFailureMockData.single(seed: seed),
      3 => PolicyDeniedFailureMockData.single(seed: seed),
      4 => NotFoundFailureMockData.single(seed: seed),
      5 => ConflictFailureMockData.single(seed: seed),
      6 => CancelledFailureMockData.single(seed: seed),
      7 => InterruptedFailureMockData.single(seed: seed),
      8 => StorageFailureMockData.single(seed: seed),
      9 => UnexpectedFailureMockData.single(seed: seed),
      _ => throw StateError('seed outside the rotation'),
    };
  }

  static List<AppFailure> list({int count = 10}) {
    return List<AppFailure>.generate(count, (index) => single(seed: index));
  }
}

class NetworkFailureMockData {
  NetworkFailureMockData._();

  static NetworkFailure single({int seed = 0}) {
    return NetworkFailure.fromTrusted(
      message: 'message-${seed}',
      traceId: 'traceid-${seed}',
      isRetryable: (seed + 248) % 2 == 0,
      code: 'code-${seed}',
      statusCode: seed % 97 + 535,
    );
  }

  static List<NetworkFailure> list({int count = 10}) {
    return List<NetworkFailure>.generate(count, (index) => single(seed: index));
  }
}

class TimeoutFailureMockData {
  TimeoutFailureMockData._();

  static TimeoutFailure single({int seed = 0}) {
    return TimeoutFailure.fromTrusted(
      message: 'message-${seed}',
      traceId: 'traceid-${seed}',
      isRetryable: (seed + 248) % 2 == 0,
      code: 'code-${seed}',
      timeout: Duration(hours: seed + 945),
    );
  }

  static List<TimeoutFailure> list({int count = 10}) {
    return List<TimeoutFailure>.generate(count, (index) => single(seed: index));
  }
}

class BoundaryViolationFailureMockData {
  BoundaryViolationFailureMockData._();

  static BoundaryViolationFailure single({int seed = 0}) {
    return BoundaryViolationFailure.fromTrusted(
      message: 'message-${seed}',
      traceId: 'traceid-${seed}',
      isRetryable: (seed + 248) % 2 == 0,
      code: 'code-${seed}',
      violations: [],
    );
  }

  static List<BoundaryViolationFailure> list({int count = 10}) {
    return List<BoundaryViolationFailure>.generate(
      count,
      (index) => single(seed: index),
    );
  }
}

class PolicyDeniedFailureMockData {
  PolicyDeniedFailureMockData._();

  static PolicyDeniedFailure single({int seed = 0}) {
    return PolicyDeniedFailure.fromTrusted(
      message: 'message-${seed}',
      traceId: 'traceid-${seed}',
      isRetryable: (seed + 248) % 2 == 0,
      code: 'code-${seed}',
      reason: 'reason-${seed}',
    );
  }

  static List<PolicyDeniedFailure> list({int count = 10}) {
    return List<PolicyDeniedFailure>.generate(
      count,
      (index) => single(seed: index),
    );
  }
}

class NotFoundFailureMockData {
  NotFoundFailureMockData._();

  static NotFoundFailure single({int seed = 0}) {
    return NotFoundFailure.fromTrusted(
      message: 'message-${seed}',
      traceId: 'traceid-${seed}',
      isRetryable: (seed + 248) % 2 == 0,
      code: 'code-${seed}',
      resourceType: 'resourcetype-${seed}',
      resourceId: 'resourceid-${seed}',
    );
  }

  static List<NotFoundFailure> list({int count = 10}) {
    return List<NotFoundFailure>.generate(
      count,
      (index) => single(seed: index),
    );
  }
}

class ConflictFailureMockData {
  ConflictFailureMockData._();

  static ConflictFailure single({int seed = 0}) {
    return ConflictFailure.fromTrusted(
      message: 'message-${seed}',
      traceId: 'traceid-${seed}',
      isRetryable: (seed + 248) % 2 == 0,
      code: 'code-${seed}',
      localPatchWire: {},
      remotePatchWire: {},
    );
  }

  static List<ConflictFailure> list({int count = 10}) {
    return List<ConflictFailure>.generate(
      count,
      (index) => single(seed: index),
    );
  }
}

class CancelledFailureMockData {
  CancelledFailureMockData._();

  static CancelledFailure single({int seed = 0}) {
    return CancelledFailure.fromTrusted(
      message: 'message-${seed}',
      traceId: 'traceid-${seed}',
      isRetryable: (seed + 248) % 2 == 0,
      code: 'code-${seed}',
    );
  }

  static List<CancelledFailure> list({int count = 10}) {
    return List<CancelledFailure>.generate(
      count,
      (index) => single(seed: index),
    );
  }
}

class InterruptedFailureMockData {
  InterruptedFailureMockData._();

  static InterruptedFailure single({int seed = 0}) {
    return InterruptedFailure.fromTrusted(
      message: 'message-${seed}',
      traceId: 'traceid-${seed}',
      isRetryable: (seed + 248) % 2 == 0,
      code: 'code-${seed}',
      intentDigest: 'intentdigest-${seed}',
    );
  }

  static List<InterruptedFailure> list({int count = 10}) {
    return List<InterruptedFailure>.generate(
      count,
      (index) => single(seed: index),
    );
  }
}

class StorageFailureMockData {
  StorageFailureMockData._();

  static StorageFailure single({int seed = 0}) {
    return StorageFailure.fromTrusted(
      message: 'message-${seed}',
      traceId: 'traceid-${seed}',
      isRetryable: (seed + 248) % 2 == 0,
      code: 'code-${seed}',
      layer: 'layer-${seed}',
    );
  }

  static List<StorageFailure> list({int count = 10}) {
    return List<StorageFailure>.generate(count, (index) => single(seed: index));
  }
}

class UnexpectedFailureMockData {
  UnexpectedFailureMockData._();

  static UnexpectedFailure single({int seed = 0}) {
    return UnexpectedFailure.fromTrusted(
      message: 'message-${seed}',
      traceId: 'traceid-${seed}',
      isRetryable: (seed + 248) % 2 == 0,
      code: 'code-${seed}',
      cause: 'cause-${seed}',
      stackTrace: 'stacktrace-${seed}',
    );
  }

  static List<UnexpectedFailure> list({int count = 10}) {
    return List<UnexpectedFailure>.generate(
      count,
      (index) => single(seed: index),
    );
  }
}

String _boundaryDescribe(Object? value) {
  if (value == null) return 'null';
  final text = value.toString();
  final clipped = text.length > 60 ? '${text.substring(0, 60)}…' : text;
  return '${value.runtimeType} ("$clipped")';
}

T? _boundaryAs<T>(Object? value, String path, List<FieldViolation> violations) {
  if (value is T) return value;
  violations.add(
    FieldViolation(
      path: path,
      expected: '$T',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

Map<String, Object?>? _boundaryObject(
  Object? value,
  String path,
  List<FieldViolation> violations,
) {
  if (value is Map<String, Object?>) return value;
  violations.add(
    FieldViolation(
      path: path,
      expected: 'Map<String, Object?>',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

List<Object?>? _boundaryList(
  Object? value,
  String path,
  List<FieldViolation> violations,
) {
  if (value is List<Object?>) return value;
  if (value is List) return List<Object?>.of(value);
  violations.add(
    FieldViolation(
      path: path,
      expected: 'List<Object?>',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

/// Typed lenses over [NetworkFailure] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `NetworkFailure.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class NetworkFailureLenses {
  const NetworkFailureLenses();

  ZorphyLens<NetworkFailure, String> get message =>
      const ZorphyLens<NetworkFailure, String>(
        path: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static String _getMessage(NetworkFailure root) => root.message;

  static NetworkFailure _setMessage(NetworkFailure root, String value) =>
      root.copyWith(message: value);

  ZorphyLens<NetworkFailure, String?> get traceId =>
      const ZorphyLens<NetworkFailure, String?>(
        path: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static String? _getTraceId(NetworkFailure root) => root.traceId;

  static NetworkFailure _setTraceId(NetworkFailure root, String? value) =>
      root.copyWith(traceId: value);

  ZorphyLens<NetworkFailure, bool> get isRetryable =>
      const ZorphyLens<NetworkFailure, bool>(
        path: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static bool _getIsRetryable(NetworkFailure root) => root.isRetryable;

  static NetworkFailure _setIsRetryable(NetworkFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  ZorphyLens<NetworkFailure, String?> get code =>
      const ZorphyLens<NetworkFailure, String?>(
        path: '/code',
        get: _getCode,
        set: _setCode,
      );

  static String? _getCode(NetworkFailure root) => root.code;

  static NetworkFailure _setCode(NetworkFailure root, String? value) =>
      root.copyWith(code: value);

  ZorphyLens<NetworkFailure, int?> get statusCode =>
      const ZorphyLens<NetworkFailure, int?>(
        path: '/statusCode',
        get: _getStatusCode,
        set: _setStatusCode,
      );

  static int? _getStatusCode(NetworkFailure root) => root.statusCode;

  static NetworkFailure _setStatusCode(NetworkFailure root, int? value) =>
      root.copyWith(statusCode: value);
}

/// Typed lenses over [TimeoutFailure] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `TimeoutFailure.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class TimeoutFailureLenses {
  const TimeoutFailureLenses();

  ZorphyLens<TimeoutFailure, String> get message =>
      const ZorphyLens<TimeoutFailure, String>(
        path: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static String _getMessage(TimeoutFailure root) => root.message;

  static TimeoutFailure _setMessage(TimeoutFailure root, String value) =>
      root.copyWith(message: value);

  ZorphyLens<TimeoutFailure, String?> get traceId =>
      const ZorphyLens<TimeoutFailure, String?>(
        path: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static String? _getTraceId(TimeoutFailure root) => root.traceId;

  static TimeoutFailure _setTraceId(TimeoutFailure root, String? value) =>
      root.copyWith(traceId: value);

  ZorphyLens<TimeoutFailure, bool> get isRetryable =>
      const ZorphyLens<TimeoutFailure, bool>(
        path: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static bool _getIsRetryable(TimeoutFailure root) => root.isRetryable;

  static TimeoutFailure _setIsRetryable(TimeoutFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  ZorphyLens<TimeoutFailure, String?> get code =>
      const ZorphyLens<TimeoutFailure, String?>(
        path: '/code',
        get: _getCode,
        set: _setCode,
      );

  static String? _getCode(TimeoutFailure root) => root.code;

  static TimeoutFailure _setCode(TimeoutFailure root, String? value) =>
      root.copyWith(code: value);

  ZorphyLens<TimeoutFailure, Duration?> get timeout =>
      const ZorphyLens<TimeoutFailure, Duration?>(
        path: '/timeout',
        get: _getTimeout,
        set: _setTimeout,
      );

  static Duration? _getTimeout(TimeoutFailure root) => root.timeout;

  static TimeoutFailure _setTimeout(TimeoutFailure root, Duration? value) =>
      root.copyWith(timeout: value);
}

/// Typed lenses over [BoundaryViolationFailure] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `BoundaryViolationFailure.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class BoundaryViolationFailureLenses {
  const BoundaryViolationFailureLenses();

  ZorphyLens<BoundaryViolationFailure, String> get message =>
      const ZorphyLens<BoundaryViolationFailure, String>(
        path: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static String _getMessage(BoundaryViolationFailure root) => root.message;

  static BoundaryViolationFailure _setMessage(
    BoundaryViolationFailure root,
    String value,
  ) => root.copyWith(message: value);

  ZorphyLens<BoundaryViolationFailure, String?> get traceId =>
      const ZorphyLens<BoundaryViolationFailure, String?>(
        path: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static String? _getTraceId(BoundaryViolationFailure root) => root.traceId;

  static BoundaryViolationFailure _setTraceId(
    BoundaryViolationFailure root,
    String? value,
  ) => root.copyWith(traceId: value);

  ZorphyLens<BoundaryViolationFailure, bool> get isRetryable =>
      const ZorphyLens<BoundaryViolationFailure, bool>(
        path: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static bool _getIsRetryable(BoundaryViolationFailure root) =>
      root.isRetryable;

  static BoundaryViolationFailure _setIsRetryable(
    BoundaryViolationFailure root,
    bool value,
  ) => root.copyWith(isRetryable: value);

  ZorphyLens<BoundaryViolationFailure, String?> get code =>
      const ZorphyLens<BoundaryViolationFailure, String?>(
        path: '/code',
        get: _getCode,
        set: _setCode,
      );

  static String? _getCode(BoundaryViolationFailure root) => root.code;

  static BoundaryViolationFailure _setCode(
    BoundaryViolationFailure root,
    String? value,
  ) => root.copyWith(code: value);

  ZorphyLens<BoundaryViolationFailure, List<FieldViolation>> get violations =>
      const ZorphyLens<BoundaryViolationFailure, List<FieldViolation>>(
        path: '/violations',
        get: _getViolations,
        set: _setViolations,
      );

  static List<FieldViolation> _getViolations(BoundaryViolationFailure root) =>
      root.violations;

  static BoundaryViolationFailure _setViolations(
    BoundaryViolationFailure root,
    List<FieldViolation> value,
  ) => root.copyWith(violations: value);
}

/// Typed lenses over [PolicyDeniedFailure] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `PolicyDeniedFailure.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class PolicyDeniedFailureLenses {
  const PolicyDeniedFailureLenses();

  ZorphyLens<PolicyDeniedFailure, String> get message =>
      const ZorphyLens<PolicyDeniedFailure, String>(
        path: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static String _getMessage(PolicyDeniedFailure root) => root.message;

  static PolicyDeniedFailure _setMessage(
    PolicyDeniedFailure root,
    String value,
  ) => root.copyWith(message: value);

  ZorphyLens<PolicyDeniedFailure, String?> get traceId =>
      const ZorphyLens<PolicyDeniedFailure, String?>(
        path: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static String? _getTraceId(PolicyDeniedFailure root) => root.traceId;

  static PolicyDeniedFailure _setTraceId(
    PolicyDeniedFailure root,
    String? value,
  ) => root.copyWith(traceId: value);

  ZorphyLens<PolicyDeniedFailure, bool> get isRetryable =>
      const ZorphyLens<PolicyDeniedFailure, bool>(
        path: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static bool _getIsRetryable(PolicyDeniedFailure root) => root.isRetryable;

  static PolicyDeniedFailure _setIsRetryable(
    PolicyDeniedFailure root,
    bool value,
  ) => root.copyWith(isRetryable: value);

  ZorphyLens<PolicyDeniedFailure, String?> get code =>
      const ZorphyLens<PolicyDeniedFailure, String?>(
        path: '/code',
        get: _getCode,
        set: _setCode,
      );

  static String? _getCode(PolicyDeniedFailure root) => root.code;

  static PolicyDeniedFailure _setCode(
    PolicyDeniedFailure root,
    String? value,
  ) => root.copyWith(code: value);

  ZorphyLens<PolicyDeniedFailure, String> get reason =>
      const ZorphyLens<PolicyDeniedFailure, String>(
        path: '/reason',
        get: _getReason,
        set: _setReason,
      );

  static String _getReason(PolicyDeniedFailure root) => root.reason;

  static PolicyDeniedFailure _setReason(
    PolicyDeniedFailure root,
    String value,
  ) => root.copyWith(reason: value);
}

/// Typed lenses over [NotFoundFailure] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `NotFoundFailure.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class NotFoundFailureLenses {
  const NotFoundFailureLenses();

  ZorphyLens<NotFoundFailure, String> get message =>
      const ZorphyLens<NotFoundFailure, String>(
        path: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static String _getMessage(NotFoundFailure root) => root.message;

  static NotFoundFailure _setMessage(NotFoundFailure root, String value) =>
      root.copyWith(message: value);

  ZorphyLens<NotFoundFailure, String?> get traceId =>
      const ZorphyLens<NotFoundFailure, String?>(
        path: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static String? _getTraceId(NotFoundFailure root) => root.traceId;

  static NotFoundFailure _setTraceId(NotFoundFailure root, String? value) =>
      root.copyWith(traceId: value);

  ZorphyLens<NotFoundFailure, bool> get isRetryable =>
      const ZorphyLens<NotFoundFailure, bool>(
        path: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static bool _getIsRetryable(NotFoundFailure root) => root.isRetryable;

  static NotFoundFailure _setIsRetryable(NotFoundFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  ZorphyLens<NotFoundFailure, String?> get code =>
      const ZorphyLens<NotFoundFailure, String?>(
        path: '/code',
        get: _getCode,
        set: _setCode,
      );

  static String? _getCode(NotFoundFailure root) => root.code;

  static NotFoundFailure _setCode(NotFoundFailure root, String? value) =>
      root.copyWith(code: value);

  ZorphyLens<NotFoundFailure, String?> get resourceType =>
      const ZorphyLens<NotFoundFailure, String?>(
        path: '/resourceType',
        get: _getResourceType,
        set: _setResourceType,
      );

  static String? _getResourceType(NotFoundFailure root) => root.resourceType;

  static NotFoundFailure _setResourceType(
    NotFoundFailure root,
    String? value,
  ) => root.copyWith(resourceType: value);

  ZorphyLens<NotFoundFailure, String?> get resourceId =>
      const ZorphyLens<NotFoundFailure, String?>(
        path: '/resourceId',
        get: _getResourceId,
        set: _setResourceId,
      );

  static String? _getResourceId(NotFoundFailure root) => root.resourceId;

  static NotFoundFailure _setResourceId(NotFoundFailure root, String? value) =>
      root.copyWith(resourceId: value);
}

/// Typed lenses over [ConflictFailure] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `ConflictFailure.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class ConflictFailureLenses {
  const ConflictFailureLenses();

  ZorphyLens<ConflictFailure, String> get message =>
      const ZorphyLens<ConflictFailure, String>(
        path: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static String _getMessage(ConflictFailure root) => root.message;

  static ConflictFailure _setMessage(ConflictFailure root, String value) =>
      root.copyWith(message: value);

  ZorphyLens<ConflictFailure, String?> get traceId =>
      const ZorphyLens<ConflictFailure, String?>(
        path: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static String? _getTraceId(ConflictFailure root) => root.traceId;

  static ConflictFailure _setTraceId(ConflictFailure root, String? value) =>
      root.copyWith(traceId: value);

  ZorphyLens<ConflictFailure, bool> get isRetryable =>
      const ZorphyLens<ConflictFailure, bool>(
        path: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static bool _getIsRetryable(ConflictFailure root) => root.isRetryable;

  static ConflictFailure _setIsRetryable(ConflictFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  ZorphyLens<ConflictFailure, String?> get code =>
      const ZorphyLens<ConflictFailure, String?>(
        path: '/code',
        get: _getCode,
        set: _setCode,
      );

  static String? _getCode(ConflictFailure root) => root.code;

  static ConflictFailure _setCode(ConflictFailure root, String? value) =>
      root.copyWith(code: value);

  ZorphyLens<ConflictFailure, Map<String, Object?>?> get localPatchWire =>
      const ZorphyLens<ConflictFailure, Map<String, Object?>?>(
        path: '/localPatchWire',
        get: _getLocalPatchWire,
        set: _setLocalPatchWire,
      );

  static Map<String, Object?>? _getLocalPatchWire(ConflictFailure root) =>
      root.localPatchWire;

  static ConflictFailure _setLocalPatchWire(
    ConflictFailure root,
    Map<String, Object?>? value,
  ) => root.copyWith(localPatchWire: value);

  ZorphyLens<ConflictFailure, Map<String, Object?>?> get remotePatchWire =>
      const ZorphyLens<ConflictFailure, Map<String, Object?>?>(
        path: '/remotePatchWire',
        get: _getRemotePatchWire,
        set: _setRemotePatchWire,
      );

  static Map<String, Object?>? _getRemotePatchWire(ConflictFailure root) =>
      root.remotePatchWire;

  static ConflictFailure _setRemotePatchWire(
    ConflictFailure root,
    Map<String, Object?>? value,
  ) => root.copyWith(remotePatchWire: value);
}

/// Typed lenses over [CancelledFailure] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `CancelledFailure.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class CancelledFailureLenses {
  const CancelledFailureLenses();

  ZorphyLens<CancelledFailure, String> get message =>
      const ZorphyLens<CancelledFailure, String>(
        path: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static String _getMessage(CancelledFailure root) => root.message;

  static CancelledFailure _setMessage(CancelledFailure root, String value) =>
      root.copyWith(message: value);

  ZorphyLens<CancelledFailure, String?> get traceId =>
      const ZorphyLens<CancelledFailure, String?>(
        path: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static String? _getTraceId(CancelledFailure root) => root.traceId;

  static CancelledFailure _setTraceId(CancelledFailure root, String? value) =>
      root.copyWith(traceId: value);

  ZorphyLens<CancelledFailure, bool> get isRetryable =>
      const ZorphyLens<CancelledFailure, bool>(
        path: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static bool _getIsRetryable(CancelledFailure root) => root.isRetryable;

  static CancelledFailure _setIsRetryable(CancelledFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  ZorphyLens<CancelledFailure, String?> get code =>
      const ZorphyLens<CancelledFailure, String?>(
        path: '/code',
        get: _getCode,
        set: _setCode,
      );

  static String? _getCode(CancelledFailure root) => root.code;

  static CancelledFailure _setCode(CancelledFailure root, String? value) =>
      root.copyWith(code: value);
}

/// Typed lenses over [InterruptedFailure] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `InterruptedFailure.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class InterruptedFailureLenses {
  const InterruptedFailureLenses();

  ZorphyLens<InterruptedFailure, String> get message =>
      const ZorphyLens<InterruptedFailure, String>(
        path: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static String _getMessage(InterruptedFailure root) => root.message;

  static InterruptedFailure _setMessage(
    InterruptedFailure root,
    String value,
  ) => root.copyWith(message: value);

  ZorphyLens<InterruptedFailure, String?> get traceId =>
      const ZorphyLens<InterruptedFailure, String?>(
        path: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static String? _getTraceId(InterruptedFailure root) => root.traceId;

  static InterruptedFailure _setTraceId(
    InterruptedFailure root,
    String? value,
  ) => root.copyWith(traceId: value);

  ZorphyLens<InterruptedFailure, bool> get isRetryable =>
      const ZorphyLens<InterruptedFailure, bool>(
        path: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static bool _getIsRetryable(InterruptedFailure root) => root.isRetryable;

  static InterruptedFailure _setIsRetryable(
    InterruptedFailure root,
    bool value,
  ) => root.copyWith(isRetryable: value);

  ZorphyLens<InterruptedFailure, String?> get code =>
      const ZorphyLens<InterruptedFailure, String?>(
        path: '/code',
        get: _getCode,
        set: _setCode,
      );

  static String? _getCode(InterruptedFailure root) => root.code;

  static InterruptedFailure _setCode(InterruptedFailure root, String? value) =>
      root.copyWith(code: value);

  ZorphyLens<InterruptedFailure, String?> get intentDigest =>
      const ZorphyLens<InterruptedFailure, String?>(
        path: '/intentDigest',
        get: _getIntentDigest,
        set: _setIntentDigest,
      );

  static String? _getIntentDigest(InterruptedFailure root) => root.intentDigest;

  static InterruptedFailure _setIntentDigest(
    InterruptedFailure root,
    String? value,
  ) => root.copyWith(intentDigest: value);
}

/// Typed lenses over [StorageFailure] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `StorageFailure.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class StorageFailureLenses {
  const StorageFailureLenses();

  ZorphyLens<StorageFailure, String> get message =>
      const ZorphyLens<StorageFailure, String>(
        path: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static String _getMessage(StorageFailure root) => root.message;

  static StorageFailure _setMessage(StorageFailure root, String value) =>
      root.copyWith(message: value);

  ZorphyLens<StorageFailure, String?> get traceId =>
      const ZorphyLens<StorageFailure, String?>(
        path: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static String? _getTraceId(StorageFailure root) => root.traceId;

  static StorageFailure _setTraceId(StorageFailure root, String? value) =>
      root.copyWith(traceId: value);

  ZorphyLens<StorageFailure, bool> get isRetryable =>
      const ZorphyLens<StorageFailure, bool>(
        path: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static bool _getIsRetryable(StorageFailure root) => root.isRetryable;

  static StorageFailure _setIsRetryable(StorageFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  ZorphyLens<StorageFailure, String?> get code =>
      const ZorphyLens<StorageFailure, String?>(
        path: '/code',
        get: _getCode,
        set: _setCode,
      );

  static String? _getCode(StorageFailure root) => root.code;

  static StorageFailure _setCode(StorageFailure root, String? value) =>
      root.copyWith(code: value);

  ZorphyLens<StorageFailure, String> get layer =>
      const ZorphyLens<StorageFailure, String>(
        path: '/layer',
        get: _getLayer,
        set: _setLayer,
      );

  static String _getLayer(StorageFailure root) => root.layer;

  static StorageFailure _setLayer(StorageFailure root, String value) =>
      root.copyWith(layer: value);
}

/// Typed lenses over [UnexpectedFailure] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `UnexpectedFailure.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class UnexpectedFailureLenses {
  const UnexpectedFailureLenses();

  ZorphyLens<UnexpectedFailure, String> get message =>
      const ZorphyLens<UnexpectedFailure, String>(
        path: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static String _getMessage(UnexpectedFailure root) => root.message;

  static UnexpectedFailure _setMessage(UnexpectedFailure root, String value) =>
      root.copyWith(message: value);

  ZorphyLens<UnexpectedFailure, String?> get traceId =>
      const ZorphyLens<UnexpectedFailure, String?>(
        path: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static String? _getTraceId(UnexpectedFailure root) => root.traceId;

  static UnexpectedFailure _setTraceId(UnexpectedFailure root, String? value) =>
      root.copyWith(traceId: value);

  ZorphyLens<UnexpectedFailure, bool> get isRetryable =>
      const ZorphyLens<UnexpectedFailure, bool>(
        path: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static bool _getIsRetryable(UnexpectedFailure root) => root.isRetryable;

  static UnexpectedFailure _setIsRetryable(
    UnexpectedFailure root,
    bool value,
  ) => root.copyWith(isRetryable: value);

  ZorphyLens<UnexpectedFailure, String?> get code =>
      const ZorphyLens<UnexpectedFailure, String?>(
        path: '/code',
        get: _getCode,
        set: _setCode,
      );

  static String? _getCode(UnexpectedFailure root) => root.code;

  static UnexpectedFailure _setCode(UnexpectedFailure root, String? value) =>
      root.copyWith(code: value);

  ZorphyLens<UnexpectedFailure, String?> get cause =>
      const ZorphyLens<UnexpectedFailure, String?>(
        path: '/cause',
        get: _getCause,
        set: _setCause,
      );

  static String? _getCause(UnexpectedFailure root) => root.cause;

  static UnexpectedFailure _setCause(UnexpectedFailure root, String? value) =>
      root.copyWith(cause: value);

  ZorphyLens<UnexpectedFailure, String?> get stackTrace =>
      const ZorphyLens<UnexpectedFailure, String?>(
        path: '/stackTrace',
        get: _getStackTrace,
        set: _setStackTrace,
      );

  static String? _getStackTrace(UnexpectedFailure root) => root.stackTrace;

  static UnexpectedFailure _setStackTrace(
    UnexpectedFailure root,
    String? value,
  ) => root.copyWith(stackTrace: value);
}

/// Typed field descriptors over [NetworkFailure] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `NetworkFailureFields.all`.
abstract final class NetworkFailureFields {
  static const ZorphyField<NetworkFailure, String> message =
      ZorphyField<NetworkFailure, String>(
        name: 'message',
        jsonKey: 'message',
        pointer: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static const ZorphyField<NetworkFailure, String?> traceId =
      ZorphyField<NetworkFailure, String?>(
        name: 'traceId',
        jsonKey: 'traceId',
        pointer: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static const ZorphyField<NetworkFailure, bool> isRetryable =
      ZorphyField<NetworkFailure, bool>(
        name: 'isRetryable',
        jsonKey: 'isRetryable',
        pointer: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static const ZorphyField<NetworkFailure, String?> code =
      ZorphyField<NetworkFailure, String?>(
        name: 'code',
        jsonKey: 'code',
        pointer: '/code',
        get: _getCode,
        set: _setCode,
      );

  static const ZorphyField<NetworkFailure, int?> statusCode =
      ZorphyField<NetworkFailure, int?>(
        name: 'statusCode',
        jsonKey: 'statusCode',
        pointer: '/statusCode',
        get: _getStatusCode,
        set: _setStatusCode,
      );

  static final List<ZorphyField<NetworkFailure, Object?>> all =
      List.unmodifiable([
        message.asObject,
        traceId.asObject,
        isRetryable.asObject,
        code.asObject,
        statusCode.asObject,
      ]);

  static String _getMessage(NetworkFailure root) => root.message;

  static NetworkFailure _setMessage(NetworkFailure root, String value) =>
      root.copyWith(message: value);

  static String? _getTraceId(NetworkFailure root) => root.traceId;

  static NetworkFailure _setTraceId(NetworkFailure root, String? value) =>
      root.copyWith(traceId: value);

  static bool _getIsRetryable(NetworkFailure root) => root.isRetryable;

  static NetworkFailure _setIsRetryable(NetworkFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  static String? _getCode(NetworkFailure root) => root.code;

  static NetworkFailure _setCode(NetworkFailure root, String? value) =>
      root.copyWith(code: value);

  static int? _getStatusCode(NetworkFailure root) => root.statusCode;

  static NetworkFailure _setStatusCode(NetworkFailure root, int? value) =>
      root.copyWith(statusCode: value);
}

/// Typed field descriptors over [TimeoutFailure] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `TimeoutFailureFields.all`.
abstract final class TimeoutFailureFields {
  static const ZorphyField<TimeoutFailure, String> message =
      ZorphyField<TimeoutFailure, String>(
        name: 'message',
        jsonKey: 'message',
        pointer: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static const ZorphyField<TimeoutFailure, String?> traceId =
      ZorphyField<TimeoutFailure, String?>(
        name: 'traceId',
        jsonKey: 'traceId',
        pointer: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static const ZorphyField<TimeoutFailure, bool> isRetryable =
      ZorphyField<TimeoutFailure, bool>(
        name: 'isRetryable',
        jsonKey: 'isRetryable',
        pointer: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static const ZorphyField<TimeoutFailure, String?> code =
      ZorphyField<TimeoutFailure, String?>(
        name: 'code',
        jsonKey: 'code',
        pointer: '/code',
        get: _getCode,
        set: _setCode,
      );

  static const ZorphyField<TimeoutFailure, Duration?> timeout =
      ZorphyField<TimeoutFailure, Duration?>(
        name: 'timeout',
        jsonKey: 'timeout',
        pointer: '/timeout',
        get: _getTimeout,
        set: _setTimeout,
      );

  static final List<ZorphyField<TimeoutFailure, Object?>> all =
      List.unmodifiable([
        message.asObject,
        traceId.asObject,
        isRetryable.asObject,
        code.asObject,
        timeout.asObject,
      ]);

  static String _getMessage(TimeoutFailure root) => root.message;

  static TimeoutFailure _setMessage(TimeoutFailure root, String value) =>
      root.copyWith(message: value);

  static String? _getTraceId(TimeoutFailure root) => root.traceId;

  static TimeoutFailure _setTraceId(TimeoutFailure root, String? value) =>
      root.copyWith(traceId: value);

  static bool _getIsRetryable(TimeoutFailure root) => root.isRetryable;

  static TimeoutFailure _setIsRetryable(TimeoutFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  static String? _getCode(TimeoutFailure root) => root.code;

  static TimeoutFailure _setCode(TimeoutFailure root, String? value) =>
      root.copyWith(code: value);

  static Duration? _getTimeout(TimeoutFailure root) => root.timeout;

  static TimeoutFailure _setTimeout(TimeoutFailure root, Duration? value) =>
      root.copyWith(timeout: value);
}

/// Typed field descriptors over [BoundaryViolationFailure] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `BoundaryViolationFailureFields.all`.
abstract final class BoundaryViolationFailureFields {
  static const ZorphyField<BoundaryViolationFailure, String> message =
      ZorphyField<BoundaryViolationFailure, String>(
        name: 'message',
        jsonKey: 'message',
        pointer: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static const ZorphyField<BoundaryViolationFailure, String?> traceId =
      ZorphyField<BoundaryViolationFailure, String?>(
        name: 'traceId',
        jsonKey: 'traceId',
        pointer: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static const ZorphyField<BoundaryViolationFailure, bool> isRetryable =
      ZorphyField<BoundaryViolationFailure, bool>(
        name: 'isRetryable',
        jsonKey: 'isRetryable',
        pointer: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static const ZorphyField<BoundaryViolationFailure, String?> code =
      ZorphyField<BoundaryViolationFailure, String?>(
        name: 'code',
        jsonKey: 'code',
        pointer: '/code',
        get: _getCode,
        set: _setCode,
      );

  static const ZorphyField<BoundaryViolationFailure, List<FieldViolation>>
  violations = ZorphyField<BoundaryViolationFailure, List<FieldViolation>>(
    name: 'violations',
    jsonKey: 'violations',
    pointer: '/violations',
    get: _getViolations,
    set: _setViolations,
  );

  static final List<ZorphyField<BoundaryViolationFailure, Object?>> all =
      List.unmodifiable([
        message.asObject,
        traceId.asObject,
        isRetryable.asObject,
        code.asObject,
        violations.asObject,
      ]);

  static String _getMessage(BoundaryViolationFailure root) => root.message;

  static BoundaryViolationFailure _setMessage(
    BoundaryViolationFailure root,
    String value,
  ) => root.copyWith(message: value);

  static String? _getTraceId(BoundaryViolationFailure root) => root.traceId;

  static BoundaryViolationFailure _setTraceId(
    BoundaryViolationFailure root,
    String? value,
  ) => root.copyWith(traceId: value);

  static bool _getIsRetryable(BoundaryViolationFailure root) =>
      root.isRetryable;

  static BoundaryViolationFailure _setIsRetryable(
    BoundaryViolationFailure root,
    bool value,
  ) => root.copyWith(isRetryable: value);

  static String? _getCode(BoundaryViolationFailure root) => root.code;

  static BoundaryViolationFailure _setCode(
    BoundaryViolationFailure root,
    String? value,
  ) => root.copyWith(code: value);

  static List<FieldViolation> _getViolations(BoundaryViolationFailure root) =>
      root.violations;

  static BoundaryViolationFailure _setViolations(
    BoundaryViolationFailure root,
    List<FieldViolation> value,
  ) => root.copyWith(violations: value);
}

/// Typed field descriptors over [PolicyDeniedFailure] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `PolicyDeniedFailureFields.all`.
abstract final class PolicyDeniedFailureFields {
  static const ZorphyField<PolicyDeniedFailure, String> message =
      ZorphyField<PolicyDeniedFailure, String>(
        name: 'message',
        jsonKey: 'message',
        pointer: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static const ZorphyField<PolicyDeniedFailure, String?> traceId =
      ZorphyField<PolicyDeniedFailure, String?>(
        name: 'traceId',
        jsonKey: 'traceId',
        pointer: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static const ZorphyField<PolicyDeniedFailure, bool> isRetryable =
      ZorphyField<PolicyDeniedFailure, bool>(
        name: 'isRetryable',
        jsonKey: 'isRetryable',
        pointer: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static const ZorphyField<PolicyDeniedFailure, String?> code =
      ZorphyField<PolicyDeniedFailure, String?>(
        name: 'code',
        jsonKey: 'code',
        pointer: '/code',
        get: _getCode,
        set: _setCode,
      );

  static const ZorphyField<PolicyDeniedFailure, String> reason =
      ZorphyField<PolicyDeniedFailure, String>(
        name: 'reason',
        jsonKey: 'reason',
        pointer: '/reason',
        get: _getReason,
        set: _setReason,
      );

  static final List<ZorphyField<PolicyDeniedFailure, Object?>> all =
      List.unmodifiable([
        message.asObject,
        traceId.asObject,
        isRetryable.asObject,
        code.asObject,
        reason.asObject,
      ]);

  static String _getMessage(PolicyDeniedFailure root) => root.message;

  static PolicyDeniedFailure _setMessage(
    PolicyDeniedFailure root,
    String value,
  ) => root.copyWith(message: value);

  static String? _getTraceId(PolicyDeniedFailure root) => root.traceId;

  static PolicyDeniedFailure _setTraceId(
    PolicyDeniedFailure root,
    String? value,
  ) => root.copyWith(traceId: value);

  static bool _getIsRetryable(PolicyDeniedFailure root) => root.isRetryable;

  static PolicyDeniedFailure _setIsRetryable(
    PolicyDeniedFailure root,
    bool value,
  ) => root.copyWith(isRetryable: value);

  static String? _getCode(PolicyDeniedFailure root) => root.code;

  static PolicyDeniedFailure _setCode(
    PolicyDeniedFailure root,
    String? value,
  ) => root.copyWith(code: value);

  static String _getReason(PolicyDeniedFailure root) => root.reason;

  static PolicyDeniedFailure _setReason(
    PolicyDeniedFailure root,
    String value,
  ) => root.copyWith(reason: value);
}

/// Typed field descriptors over [NotFoundFailure] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `NotFoundFailureFields.all`.
abstract final class NotFoundFailureFields {
  static const ZorphyField<NotFoundFailure, String> message =
      ZorphyField<NotFoundFailure, String>(
        name: 'message',
        jsonKey: 'message',
        pointer: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static const ZorphyField<NotFoundFailure, String?> traceId =
      ZorphyField<NotFoundFailure, String?>(
        name: 'traceId',
        jsonKey: 'traceId',
        pointer: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static const ZorphyField<NotFoundFailure, bool> isRetryable =
      ZorphyField<NotFoundFailure, bool>(
        name: 'isRetryable',
        jsonKey: 'isRetryable',
        pointer: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static const ZorphyField<NotFoundFailure, String?> code =
      ZorphyField<NotFoundFailure, String?>(
        name: 'code',
        jsonKey: 'code',
        pointer: '/code',
        get: _getCode,
        set: _setCode,
      );

  static const ZorphyField<NotFoundFailure, String?> resourceType =
      ZorphyField<NotFoundFailure, String?>(
        name: 'resourceType',
        jsonKey: 'resourceType',
        pointer: '/resourceType',
        get: _getResourceType,
        set: _setResourceType,
      );

  static const ZorphyField<NotFoundFailure, String?> resourceId =
      ZorphyField<NotFoundFailure, String?>(
        name: 'resourceId',
        jsonKey: 'resourceId',
        pointer: '/resourceId',
        get: _getResourceId,
        set: _setResourceId,
      );

  static final List<ZorphyField<NotFoundFailure, Object?>> all =
      List.unmodifiable([
        message.asObject,
        traceId.asObject,
        isRetryable.asObject,
        code.asObject,
        resourceType.asObject,
        resourceId.asObject,
      ]);

  static String _getMessage(NotFoundFailure root) => root.message;

  static NotFoundFailure _setMessage(NotFoundFailure root, String value) =>
      root.copyWith(message: value);

  static String? _getTraceId(NotFoundFailure root) => root.traceId;

  static NotFoundFailure _setTraceId(NotFoundFailure root, String? value) =>
      root.copyWith(traceId: value);

  static bool _getIsRetryable(NotFoundFailure root) => root.isRetryable;

  static NotFoundFailure _setIsRetryable(NotFoundFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  static String? _getCode(NotFoundFailure root) => root.code;

  static NotFoundFailure _setCode(NotFoundFailure root, String? value) =>
      root.copyWith(code: value);

  static String? _getResourceType(NotFoundFailure root) => root.resourceType;

  static NotFoundFailure _setResourceType(
    NotFoundFailure root,
    String? value,
  ) => root.copyWith(resourceType: value);

  static String? _getResourceId(NotFoundFailure root) => root.resourceId;

  static NotFoundFailure _setResourceId(NotFoundFailure root, String? value) =>
      root.copyWith(resourceId: value);
}

/// Typed field descriptors over [ConflictFailure] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `ConflictFailureFields.all`.
abstract final class ConflictFailureFields {
  static const ZorphyField<ConflictFailure, String> message =
      ZorphyField<ConflictFailure, String>(
        name: 'message',
        jsonKey: 'message',
        pointer: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static const ZorphyField<ConflictFailure, String?> traceId =
      ZorphyField<ConflictFailure, String?>(
        name: 'traceId',
        jsonKey: 'traceId',
        pointer: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static const ZorphyField<ConflictFailure, bool> isRetryable =
      ZorphyField<ConflictFailure, bool>(
        name: 'isRetryable',
        jsonKey: 'isRetryable',
        pointer: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static const ZorphyField<ConflictFailure, String?> code =
      ZorphyField<ConflictFailure, String?>(
        name: 'code',
        jsonKey: 'code',
        pointer: '/code',
        get: _getCode,
        set: _setCode,
      );

  static const ZorphyField<ConflictFailure, Map<String, Object?>?>
  localPatchWire = ZorphyField<ConflictFailure, Map<String, Object?>?>(
    name: 'localPatchWire',
    jsonKey: 'localPatchWire',
    pointer: '/localPatchWire',
    get: _getLocalPatchWire,
    set: _setLocalPatchWire,
  );

  static const ZorphyField<ConflictFailure, Map<String, Object?>?>
  remotePatchWire = ZorphyField<ConflictFailure, Map<String, Object?>?>(
    name: 'remotePatchWire',
    jsonKey: 'remotePatchWire',
    pointer: '/remotePatchWire',
    get: _getRemotePatchWire,
    set: _setRemotePatchWire,
  );

  static final List<ZorphyField<ConflictFailure, Object?>> all =
      List.unmodifiable([
        message.asObject,
        traceId.asObject,
        isRetryable.asObject,
        code.asObject,
        localPatchWire.asObject,
        remotePatchWire.asObject,
      ]);

  static String _getMessage(ConflictFailure root) => root.message;

  static ConflictFailure _setMessage(ConflictFailure root, String value) =>
      root.copyWith(message: value);

  static String? _getTraceId(ConflictFailure root) => root.traceId;

  static ConflictFailure _setTraceId(ConflictFailure root, String? value) =>
      root.copyWith(traceId: value);

  static bool _getIsRetryable(ConflictFailure root) => root.isRetryable;

  static ConflictFailure _setIsRetryable(ConflictFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  static String? _getCode(ConflictFailure root) => root.code;

  static ConflictFailure _setCode(ConflictFailure root, String? value) =>
      root.copyWith(code: value);

  static Map<String, Object?>? _getLocalPatchWire(ConflictFailure root) =>
      root.localPatchWire;

  static ConflictFailure _setLocalPatchWire(
    ConflictFailure root,
    Map<String, Object?>? value,
  ) => root.copyWith(localPatchWire: value);

  static Map<String, Object?>? _getRemotePatchWire(ConflictFailure root) =>
      root.remotePatchWire;

  static ConflictFailure _setRemotePatchWire(
    ConflictFailure root,
    Map<String, Object?>? value,
  ) => root.copyWith(remotePatchWire: value);
}

/// Typed field descriptors over [CancelledFailure] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `CancelledFailureFields.all`.
abstract final class CancelledFailureFields {
  static const ZorphyField<CancelledFailure, String> message =
      ZorphyField<CancelledFailure, String>(
        name: 'message',
        jsonKey: 'message',
        pointer: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static const ZorphyField<CancelledFailure, String?> traceId =
      ZorphyField<CancelledFailure, String?>(
        name: 'traceId',
        jsonKey: 'traceId',
        pointer: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static const ZorphyField<CancelledFailure, bool> isRetryable =
      ZorphyField<CancelledFailure, bool>(
        name: 'isRetryable',
        jsonKey: 'isRetryable',
        pointer: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static const ZorphyField<CancelledFailure, String?> code =
      ZorphyField<CancelledFailure, String?>(
        name: 'code',
        jsonKey: 'code',
        pointer: '/code',
        get: _getCode,
        set: _setCode,
      );

  static final List<ZorphyField<CancelledFailure, Object?>> all =
      List.unmodifiable([
        message.asObject,
        traceId.asObject,
        isRetryable.asObject,
        code.asObject,
      ]);

  static String _getMessage(CancelledFailure root) => root.message;

  static CancelledFailure _setMessage(CancelledFailure root, String value) =>
      root.copyWith(message: value);

  static String? _getTraceId(CancelledFailure root) => root.traceId;

  static CancelledFailure _setTraceId(CancelledFailure root, String? value) =>
      root.copyWith(traceId: value);

  static bool _getIsRetryable(CancelledFailure root) => root.isRetryable;

  static CancelledFailure _setIsRetryable(CancelledFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  static String? _getCode(CancelledFailure root) => root.code;

  static CancelledFailure _setCode(CancelledFailure root, String? value) =>
      root.copyWith(code: value);
}

/// Typed field descriptors over [InterruptedFailure] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `InterruptedFailureFields.all`.
abstract final class InterruptedFailureFields {
  static const ZorphyField<InterruptedFailure, String> message =
      ZorphyField<InterruptedFailure, String>(
        name: 'message',
        jsonKey: 'message',
        pointer: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static const ZorphyField<InterruptedFailure, String?> traceId =
      ZorphyField<InterruptedFailure, String?>(
        name: 'traceId',
        jsonKey: 'traceId',
        pointer: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static const ZorphyField<InterruptedFailure, bool> isRetryable =
      ZorphyField<InterruptedFailure, bool>(
        name: 'isRetryable',
        jsonKey: 'isRetryable',
        pointer: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static const ZorphyField<InterruptedFailure, String?> code =
      ZorphyField<InterruptedFailure, String?>(
        name: 'code',
        jsonKey: 'code',
        pointer: '/code',
        get: _getCode,
        set: _setCode,
      );

  static const ZorphyField<InterruptedFailure, String?> intentDigest =
      ZorphyField<InterruptedFailure, String?>(
        name: 'intentDigest',
        jsonKey: 'intentDigest',
        pointer: '/intentDigest',
        get: _getIntentDigest,
        set: _setIntentDigest,
      );

  static final List<ZorphyField<InterruptedFailure, Object?>> all =
      List.unmodifiable([
        message.asObject,
        traceId.asObject,
        isRetryable.asObject,
        code.asObject,
        intentDigest.asObject,
      ]);

  static String _getMessage(InterruptedFailure root) => root.message;

  static InterruptedFailure _setMessage(
    InterruptedFailure root,
    String value,
  ) => root.copyWith(message: value);

  static String? _getTraceId(InterruptedFailure root) => root.traceId;

  static InterruptedFailure _setTraceId(
    InterruptedFailure root,
    String? value,
  ) => root.copyWith(traceId: value);

  static bool _getIsRetryable(InterruptedFailure root) => root.isRetryable;

  static InterruptedFailure _setIsRetryable(
    InterruptedFailure root,
    bool value,
  ) => root.copyWith(isRetryable: value);

  static String? _getCode(InterruptedFailure root) => root.code;

  static InterruptedFailure _setCode(InterruptedFailure root, String? value) =>
      root.copyWith(code: value);

  static String? _getIntentDigest(InterruptedFailure root) => root.intentDigest;

  static InterruptedFailure _setIntentDigest(
    InterruptedFailure root,
    String? value,
  ) => root.copyWith(intentDigest: value);
}

/// Typed field descriptors over [StorageFailure] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `StorageFailureFields.all`.
abstract final class StorageFailureFields {
  static const ZorphyField<StorageFailure, String> message =
      ZorphyField<StorageFailure, String>(
        name: 'message',
        jsonKey: 'message',
        pointer: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static const ZorphyField<StorageFailure, String?> traceId =
      ZorphyField<StorageFailure, String?>(
        name: 'traceId',
        jsonKey: 'traceId',
        pointer: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static const ZorphyField<StorageFailure, bool> isRetryable =
      ZorphyField<StorageFailure, bool>(
        name: 'isRetryable',
        jsonKey: 'isRetryable',
        pointer: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static const ZorphyField<StorageFailure, String?> code =
      ZorphyField<StorageFailure, String?>(
        name: 'code',
        jsonKey: 'code',
        pointer: '/code',
        get: _getCode,
        set: _setCode,
      );

  static const ZorphyField<StorageFailure, String> layer =
      ZorphyField<StorageFailure, String>(
        name: 'layer',
        jsonKey: 'layer',
        pointer: '/layer',
        get: _getLayer,
        set: _setLayer,
      );

  static final List<ZorphyField<StorageFailure, Object?>> all =
      List.unmodifiable([
        message.asObject,
        traceId.asObject,
        isRetryable.asObject,
        code.asObject,
        layer.asObject,
      ]);

  static String _getMessage(StorageFailure root) => root.message;

  static StorageFailure _setMessage(StorageFailure root, String value) =>
      root.copyWith(message: value);

  static String? _getTraceId(StorageFailure root) => root.traceId;

  static StorageFailure _setTraceId(StorageFailure root, String? value) =>
      root.copyWith(traceId: value);

  static bool _getIsRetryable(StorageFailure root) => root.isRetryable;

  static StorageFailure _setIsRetryable(StorageFailure root, bool value) =>
      root.copyWith(isRetryable: value);

  static String? _getCode(StorageFailure root) => root.code;

  static StorageFailure _setCode(StorageFailure root, String? value) =>
      root.copyWith(code: value);

  static String _getLayer(StorageFailure root) => root.layer;

  static StorageFailure _setLayer(StorageFailure root, String value) =>
      root.copyWith(layer: value);
}

/// Typed field descriptors over [UnexpectedFailure] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `UnexpectedFailureFields.all`.
abstract final class UnexpectedFailureFields {
  static const ZorphyField<UnexpectedFailure, String> message =
      ZorphyField<UnexpectedFailure, String>(
        name: 'message',
        jsonKey: 'message',
        pointer: '/message',
        get: _getMessage,
        set: _setMessage,
      );

  static const ZorphyField<UnexpectedFailure, String?> traceId =
      ZorphyField<UnexpectedFailure, String?>(
        name: 'traceId',
        jsonKey: 'traceId',
        pointer: '/traceId',
        get: _getTraceId,
        set: _setTraceId,
      );

  static const ZorphyField<UnexpectedFailure, bool> isRetryable =
      ZorphyField<UnexpectedFailure, bool>(
        name: 'isRetryable',
        jsonKey: 'isRetryable',
        pointer: '/isRetryable',
        get: _getIsRetryable,
        set: _setIsRetryable,
      );

  static const ZorphyField<UnexpectedFailure, String?> code =
      ZorphyField<UnexpectedFailure, String?>(
        name: 'code',
        jsonKey: 'code',
        pointer: '/code',
        get: _getCode,
        set: _setCode,
      );

  static const ZorphyField<UnexpectedFailure, String?> cause =
      ZorphyField<UnexpectedFailure, String?>(
        name: 'cause',
        jsonKey: 'cause',
        pointer: '/cause',
        get: _getCause,
        set: _setCause,
      );

  static const ZorphyField<UnexpectedFailure, String?> stackTrace =
      ZorphyField<UnexpectedFailure, String?>(
        name: 'stackTrace',
        jsonKey: 'stackTrace',
        pointer: '/stackTrace',
        get: _getStackTrace,
        set: _setStackTrace,
      );

  static final List<ZorphyField<UnexpectedFailure, Object?>> all =
      List.unmodifiable([
        message.asObject,
        traceId.asObject,
        isRetryable.asObject,
        code.asObject,
        cause.asObject,
        stackTrace.asObject,
      ]);

  static String _getMessage(UnexpectedFailure root) => root.message;

  static UnexpectedFailure _setMessage(UnexpectedFailure root, String value) =>
      root.copyWith(message: value);

  static String? _getTraceId(UnexpectedFailure root) => root.traceId;

  static UnexpectedFailure _setTraceId(UnexpectedFailure root, String? value) =>
      root.copyWith(traceId: value);

  static bool _getIsRetryable(UnexpectedFailure root) => root.isRetryable;

  static UnexpectedFailure _setIsRetryable(
    UnexpectedFailure root,
    bool value,
  ) => root.copyWith(isRetryable: value);

  static String? _getCode(UnexpectedFailure root) => root.code;

  static UnexpectedFailure _setCode(UnexpectedFailure root, String? value) =>
      root.copyWith(code: value);

  static String? _getCause(UnexpectedFailure root) => root.cause;

  static UnexpectedFailure _setCause(UnexpectedFailure root, String? value) =>
      root.copyWith(cause: value);

  static String? _getStackTrace(UnexpectedFailure root) => root.stackTrace;

  static UnexpectedFailure _setStackTrace(
    UnexpectedFailure root,
    String? value,
  ) => root.copyWith(stackTrace: value);
}

extension AppFailureWhenE on AppFailure {
  T when<T>({
    required T Function(NetworkFailure) networkFailure,
    required T Function(TimeoutFailure) timeoutFailure,
    required T Function(BoundaryViolationFailure) boundaryViolationFailure,
    required T Function(PolicyDeniedFailure) policyDeniedFailure,
    required T Function(NotFoundFailure) notFoundFailure,
    required T Function(ConflictFailure) conflictFailure,
    required T Function(CancelledFailure) cancelledFailure,
    required T Function(InterruptedFailure) interruptedFailure,
    required T Function(StorageFailure) storageFailure,
    required T Function(UnexpectedFailure) unexpectedFailure,
  }) {
    return switch (this) {
      NetworkFailure value => networkFailure(value),
      TimeoutFailure value => timeoutFailure(value),
      BoundaryViolationFailure value => boundaryViolationFailure(value),
      PolicyDeniedFailure value => policyDeniedFailure(value),
      NotFoundFailure value => notFoundFailure(value),
      ConflictFailure value => conflictFailure(value),
      CancelledFailure value => cancelledFailure(value),
      InterruptedFailure value => interruptedFailure(value),
      StorageFailure value => storageFailure(value),
      UnexpectedFailure value => unexpectedFailure(value),
    };
  }

  T maybeWhen<T>({
    T Function(NetworkFailure)? networkFailure,
    T Function(TimeoutFailure)? timeoutFailure,
    T Function(BoundaryViolationFailure)? boundaryViolationFailure,
    T Function(PolicyDeniedFailure)? policyDeniedFailure,
    T Function(NotFoundFailure)? notFoundFailure,
    T Function(ConflictFailure)? conflictFailure,
    T Function(CancelledFailure)? cancelledFailure,
    T Function(InterruptedFailure)? interruptedFailure,
    T Function(StorageFailure)? storageFailure,
    T Function(UnexpectedFailure)? unexpectedFailure,
    required T Function() orElse,
  }) {
    final self = this;
    if (self is NetworkFailure) {
      final callback = networkFailure;
      return callback == null ? orElse() : callback(self);
    }
    if (self is TimeoutFailure) {
      final callback = timeoutFailure;
      return callback == null ? orElse() : callback(self);
    }
    if (self is BoundaryViolationFailure) {
      final callback = boundaryViolationFailure;
      return callback == null ? orElse() : callback(self);
    }
    if (self is PolicyDeniedFailure) {
      final callback = policyDeniedFailure;
      return callback == null ? orElse() : callback(self);
    }
    if (self is NotFoundFailure) {
      final callback = notFoundFailure;
      return callback == null ? orElse() : callback(self);
    }
    if (self is ConflictFailure) {
      final callback = conflictFailure;
      return callback == null ? orElse() : callback(self);
    }
    if (self is CancelledFailure) {
      final callback = cancelledFailure;
      return callback == null ? orElse() : callback(self);
    }
    if (self is InterruptedFailure) {
      final callback = interruptedFailure;
      return callback == null ? orElse() : callback(self);
    }
    if (self is StorageFailure) {
      final callback = storageFailure;
      return callback == null ? orElse() : callback(self);
    }
    if (self is UnexpectedFailure) {
      final callback = unexpectedFailure;
      return callback == null ? orElse() : callback(self);
    }
    return orElse();
  }
}

extension NetworkFailureMorphing on NetworkFailure {
  TimeoutFailure changeToTimeoutFailure({
    String? traceId,
    String? code,
    Duration? timeout,
  }) {
    return TimeoutFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      timeout: timeout,
    );
  }

  BoundaryViolationFailure changeToBoundaryViolationFailure({
    String? traceId,
    String? code,
    required List<FieldViolation> violations,
  }) {
    return BoundaryViolationFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      violations: violations,
    );
  }

  PolicyDeniedFailure changeToPolicyDeniedFailure({
    String? traceId,
    String? code,
    required String reason,
  }) {
    return PolicyDeniedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      reason: reason,
    );
  }

  NotFoundFailure changeToNotFoundFailure({
    String? traceId,
    String? code,
    String? resourceType,
    String? resourceId,
  }) {
    return NotFoundFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      resourceType: resourceType,
      resourceId: resourceId,
    );
  }

  ConflictFailure changeToConflictFailure({
    String? traceId,
    String? code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) {
    return ConflictFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      localPatchWire: localPatchWire,
      remotePatchWire: remotePatchWire,
    );
  }

  CancelledFailure changeToCancelledFailure({String? traceId, String? code}) {
    return CancelledFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
    );
  }

  InterruptedFailure changeToInterruptedFailure({
    String? traceId,
    String? code,
    String? intentDigest,
  }) {
    return InterruptedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      intentDigest: intentDigest,
    );
  }

  StorageFailure changeToStorageFailure({
    String? traceId,
    String? code,
    required String layer,
  }) {
    return StorageFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      layer: layer,
    );
  }

  UnexpectedFailure changeToUnexpectedFailure({
    String? traceId,
    String? code,
    String? cause,
    String? stackTrace,
  }) {
    return UnexpectedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

extension TimeoutFailureMorphing on TimeoutFailure {
  NetworkFailure changeToNetworkFailure({
    String? traceId,
    String? code,
    int? statusCode,
  }) {
    return NetworkFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      statusCode: statusCode,
    );
  }

  BoundaryViolationFailure changeToBoundaryViolationFailure({
    String? traceId,
    String? code,
    required List<FieldViolation> violations,
  }) {
    return BoundaryViolationFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      violations: violations,
    );
  }

  PolicyDeniedFailure changeToPolicyDeniedFailure({
    String? traceId,
    String? code,
    required String reason,
  }) {
    return PolicyDeniedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      reason: reason,
    );
  }

  NotFoundFailure changeToNotFoundFailure({
    String? traceId,
    String? code,
    String? resourceType,
    String? resourceId,
  }) {
    return NotFoundFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      resourceType: resourceType,
      resourceId: resourceId,
    );
  }

  ConflictFailure changeToConflictFailure({
    String? traceId,
    String? code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) {
    return ConflictFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      localPatchWire: localPatchWire,
      remotePatchWire: remotePatchWire,
    );
  }

  CancelledFailure changeToCancelledFailure({String? traceId, String? code}) {
    return CancelledFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
    );
  }

  InterruptedFailure changeToInterruptedFailure({
    String? traceId,
    String? code,
    String? intentDigest,
  }) {
    return InterruptedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      intentDigest: intentDigest,
    );
  }

  StorageFailure changeToStorageFailure({
    String? traceId,
    String? code,
    required String layer,
  }) {
    return StorageFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      layer: layer,
    );
  }

  UnexpectedFailure changeToUnexpectedFailure({
    String? traceId,
    String? code,
    String? cause,
    String? stackTrace,
  }) {
    return UnexpectedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

extension BoundaryViolationFailureMorphing on BoundaryViolationFailure {
  NetworkFailure changeToNetworkFailure({
    String? traceId,
    String? code,
    int? statusCode,
  }) {
    return NetworkFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      statusCode: statusCode,
    );
  }

  TimeoutFailure changeToTimeoutFailure({
    String? traceId,
    String? code,
    Duration? timeout,
  }) {
    return TimeoutFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      timeout: timeout,
    );
  }

  PolicyDeniedFailure changeToPolicyDeniedFailure({
    String? traceId,
    String? code,
    required String reason,
  }) {
    return PolicyDeniedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      reason: reason,
    );
  }

  NotFoundFailure changeToNotFoundFailure({
    String? traceId,
    String? code,
    String? resourceType,
    String? resourceId,
  }) {
    return NotFoundFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      resourceType: resourceType,
      resourceId: resourceId,
    );
  }

  ConflictFailure changeToConflictFailure({
    String? traceId,
    String? code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) {
    return ConflictFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      localPatchWire: localPatchWire,
      remotePatchWire: remotePatchWire,
    );
  }

  CancelledFailure changeToCancelledFailure({String? traceId, String? code}) {
    return CancelledFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
    );
  }

  InterruptedFailure changeToInterruptedFailure({
    String? traceId,
    String? code,
    String? intentDigest,
  }) {
    return InterruptedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      intentDigest: intentDigest,
    );
  }

  StorageFailure changeToStorageFailure({
    String? traceId,
    String? code,
    required String layer,
  }) {
    return StorageFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      layer: layer,
    );
  }

  UnexpectedFailure changeToUnexpectedFailure({
    String? traceId,
    String? code,
    String? cause,
    String? stackTrace,
  }) {
    return UnexpectedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

extension PolicyDeniedFailureMorphing on PolicyDeniedFailure {
  NetworkFailure changeToNetworkFailure({
    String? traceId,
    String? code,
    int? statusCode,
  }) {
    return NetworkFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      statusCode: statusCode,
    );
  }

  TimeoutFailure changeToTimeoutFailure({
    String? traceId,
    String? code,
    Duration? timeout,
  }) {
    return TimeoutFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      timeout: timeout,
    );
  }

  BoundaryViolationFailure changeToBoundaryViolationFailure({
    String? traceId,
    String? code,
    required List<FieldViolation> violations,
  }) {
    return BoundaryViolationFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      violations: violations,
    );
  }

  NotFoundFailure changeToNotFoundFailure({
    String? traceId,
    String? code,
    String? resourceType,
    String? resourceId,
  }) {
    return NotFoundFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      resourceType: resourceType,
      resourceId: resourceId,
    );
  }

  ConflictFailure changeToConflictFailure({
    String? traceId,
    String? code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) {
    return ConflictFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      localPatchWire: localPatchWire,
      remotePatchWire: remotePatchWire,
    );
  }

  CancelledFailure changeToCancelledFailure({String? traceId, String? code}) {
    return CancelledFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
    );
  }

  InterruptedFailure changeToInterruptedFailure({
    String? traceId,
    String? code,
    String? intentDigest,
  }) {
    return InterruptedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      intentDigest: intentDigest,
    );
  }

  StorageFailure changeToStorageFailure({
    String? traceId,
    String? code,
    required String layer,
  }) {
    return StorageFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      layer: layer,
    );
  }

  UnexpectedFailure changeToUnexpectedFailure({
    String? traceId,
    String? code,
    String? cause,
    String? stackTrace,
  }) {
    return UnexpectedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

extension NotFoundFailureMorphing on NotFoundFailure {
  NetworkFailure changeToNetworkFailure({
    String? traceId,
    String? code,
    int? statusCode,
  }) {
    return NetworkFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      statusCode: statusCode,
    );
  }

  TimeoutFailure changeToTimeoutFailure({
    String? traceId,
    String? code,
    Duration? timeout,
  }) {
    return TimeoutFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      timeout: timeout,
    );
  }

  BoundaryViolationFailure changeToBoundaryViolationFailure({
    String? traceId,
    String? code,
    required List<FieldViolation> violations,
  }) {
    return BoundaryViolationFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      violations: violations,
    );
  }

  PolicyDeniedFailure changeToPolicyDeniedFailure({
    String? traceId,
    String? code,
    required String reason,
  }) {
    return PolicyDeniedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      reason: reason,
    );
  }

  ConflictFailure changeToConflictFailure({
    String? traceId,
    String? code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) {
    return ConflictFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      localPatchWire: localPatchWire,
      remotePatchWire: remotePatchWire,
    );
  }

  CancelledFailure changeToCancelledFailure({String? traceId, String? code}) {
    return CancelledFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
    );
  }

  InterruptedFailure changeToInterruptedFailure({
    String? traceId,
    String? code,
    String? intentDigest,
  }) {
    return InterruptedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      intentDigest: intentDigest,
    );
  }

  StorageFailure changeToStorageFailure({
    String? traceId,
    String? code,
    required String layer,
  }) {
    return StorageFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      layer: layer,
    );
  }

  UnexpectedFailure changeToUnexpectedFailure({
    String? traceId,
    String? code,
    String? cause,
    String? stackTrace,
  }) {
    return UnexpectedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

extension ConflictFailureMorphing on ConflictFailure {
  NetworkFailure changeToNetworkFailure({
    String? traceId,
    String? code,
    int? statusCode,
  }) {
    return NetworkFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      statusCode: statusCode,
    );
  }

  TimeoutFailure changeToTimeoutFailure({
    String? traceId,
    String? code,
    Duration? timeout,
  }) {
    return TimeoutFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      timeout: timeout,
    );
  }

  BoundaryViolationFailure changeToBoundaryViolationFailure({
    String? traceId,
    String? code,
    required List<FieldViolation> violations,
  }) {
    return BoundaryViolationFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      violations: violations,
    );
  }

  PolicyDeniedFailure changeToPolicyDeniedFailure({
    String? traceId,
    String? code,
    required String reason,
  }) {
    return PolicyDeniedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      reason: reason,
    );
  }

  NotFoundFailure changeToNotFoundFailure({
    String? traceId,
    String? code,
    String? resourceType,
    String? resourceId,
  }) {
    return NotFoundFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      resourceType: resourceType,
      resourceId: resourceId,
    );
  }

  CancelledFailure changeToCancelledFailure({String? traceId, String? code}) {
    return CancelledFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
    );
  }

  InterruptedFailure changeToInterruptedFailure({
    String? traceId,
    String? code,
    String? intentDigest,
  }) {
    return InterruptedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      intentDigest: intentDigest,
    );
  }

  StorageFailure changeToStorageFailure({
    String? traceId,
    String? code,
    required String layer,
  }) {
    return StorageFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      layer: layer,
    );
  }

  UnexpectedFailure changeToUnexpectedFailure({
    String? traceId,
    String? code,
    String? cause,
    String? stackTrace,
  }) {
    return UnexpectedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

extension CancelledFailureMorphing on CancelledFailure {
  NetworkFailure changeToNetworkFailure({
    String? traceId,
    String? code,
    int? statusCode,
  }) {
    return NetworkFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      statusCode: statusCode,
    );
  }

  TimeoutFailure changeToTimeoutFailure({
    String? traceId,
    String? code,
    Duration? timeout,
  }) {
    return TimeoutFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      timeout: timeout,
    );
  }

  BoundaryViolationFailure changeToBoundaryViolationFailure({
    String? traceId,
    String? code,
    required List<FieldViolation> violations,
  }) {
    return BoundaryViolationFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      violations: violations,
    );
  }

  PolicyDeniedFailure changeToPolicyDeniedFailure({
    String? traceId,
    String? code,
    required String reason,
  }) {
    return PolicyDeniedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      reason: reason,
    );
  }

  NotFoundFailure changeToNotFoundFailure({
    String? traceId,
    String? code,
    String? resourceType,
    String? resourceId,
  }) {
    return NotFoundFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      resourceType: resourceType,
      resourceId: resourceId,
    );
  }

  ConflictFailure changeToConflictFailure({
    String? traceId,
    String? code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) {
    return ConflictFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      localPatchWire: localPatchWire,
      remotePatchWire: remotePatchWire,
    );
  }

  InterruptedFailure changeToInterruptedFailure({
    String? traceId,
    String? code,
    String? intentDigest,
  }) {
    return InterruptedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      intentDigest: intentDigest,
    );
  }

  StorageFailure changeToStorageFailure({
    String? traceId,
    String? code,
    required String layer,
  }) {
    return StorageFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      layer: layer,
    );
  }

  UnexpectedFailure changeToUnexpectedFailure({
    String? traceId,
    String? code,
    String? cause,
    String? stackTrace,
  }) {
    return UnexpectedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

extension InterruptedFailureMorphing on InterruptedFailure {
  NetworkFailure changeToNetworkFailure({
    String? traceId,
    String? code,
    int? statusCode,
  }) {
    return NetworkFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      statusCode: statusCode,
    );
  }

  TimeoutFailure changeToTimeoutFailure({
    String? traceId,
    String? code,
    Duration? timeout,
  }) {
    return TimeoutFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      timeout: timeout,
    );
  }

  BoundaryViolationFailure changeToBoundaryViolationFailure({
    String? traceId,
    String? code,
    required List<FieldViolation> violations,
  }) {
    return BoundaryViolationFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      violations: violations,
    );
  }

  PolicyDeniedFailure changeToPolicyDeniedFailure({
    String? traceId,
    String? code,
    required String reason,
  }) {
    return PolicyDeniedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      reason: reason,
    );
  }

  NotFoundFailure changeToNotFoundFailure({
    String? traceId,
    String? code,
    String? resourceType,
    String? resourceId,
  }) {
    return NotFoundFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      resourceType: resourceType,
      resourceId: resourceId,
    );
  }

  ConflictFailure changeToConflictFailure({
    String? traceId,
    String? code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) {
    return ConflictFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      localPatchWire: localPatchWire,
      remotePatchWire: remotePatchWire,
    );
  }

  CancelledFailure changeToCancelledFailure({String? traceId, String? code}) {
    return CancelledFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
    );
  }

  StorageFailure changeToStorageFailure({
    String? traceId,
    String? code,
    required String layer,
  }) {
    return StorageFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      layer: layer,
    );
  }

  UnexpectedFailure changeToUnexpectedFailure({
    String? traceId,
    String? code,
    String? cause,
    String? stackTrace,
  }) {
    return UnexpectedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

extension StorageFailureMorphing on StorageFailure {
  NetworkFailure changeToNetworkFailure({
    String? traceId,
    String? code,
    int? statusCode,
  }) {
    return NetworkFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      statusCode: statusCode,
    );
  }

  TimeoutFailure changeToTimeoutFailure({
    String? traceId,
    String? code,
    Duration? timeout,
  }) {
    return TimeoutFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      timeout: timeout,
    );
  }

  BoundaryViolationFailure changeToBoundaryViolationFailure({
    String? traceId,
    String? code,
    required List<FieldViolation> violations,
  }) {
    return BoundaryViolationFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      violations: violations,
    );
  }

  PolicyDeniedFailure changeToPolicyDeniedFailure({
    String? traceId,
    String? code,
    required String reason,
  }) {
    return PolicyDeniedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      reason: reason,
    );
  }

  NotFoundFailure changeToNotFoundFailure({
    String? traceId,
    String? code,
    String? resourceType,
    String? resourceId,
  }) {
    return NotFoundFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      resourceType: resourceType,
      resourceId: resourceId,
    );
  }

  ConflictFailure changeToConflictFailure({
    String? traceId,
    String? code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) {
    return ConflictFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      localPatchWire: localPatchWire,
      remotePatchWire: remotePatchWire,
    );
  }

  CancelledFailure changeToCancelledFailure({String? traceId, String? code}) {
    return CancelledFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
    );
  }

  InterruptedFailure changeToInterruptedFailure({
    String? traceId,
    String? code,
    String? intentDigest,
  }) {
    return InterruptedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      intentDigest: intentDigest,
    );
  }

  UnexpectedFailure changeToUnexpectedFailure({
    String? traceId,
    String? code,
    String? cause,
    String? stackTrace,
  }) {
    return UnexpectedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

extension UnexpectedFailureMorphing on UnexpectedFailure {
  NetworkFailure changeToNetworkFailure({
    String? traceId,
    String? code,
    int? statusCode,
  }) {
    return NetworkFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      statusCode: statusCode,
    );
  }

  TimeoutFailure changeToTimeoutFailure({
    String? traceId,
    String? code,
    Duration? timeout,
  }) {
    return TimeoutFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      timeout: timeout,
    );
  }

  BoundaryViolationFailure changeToBoundaryViolationFailure({
    String? traceId,
    String? code,
    required List<FieldViolation> violations,
  }) {
    return BoundaryViolationFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      violations: violations,
    );
  }

  PolicyDeniedFailure changeToPolicyDeniedFailure({
    String? traceId,
    String? code,
    required String reason,
  }) {
    return PolicyDeniedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      reason: reason,
    );
  }

  NotFoundFailure changeToNotFoundFailure({
    String? traceId,
    String? code,
    String? resourceType,
    String? resourceId,
  }) {
    return NotFoundFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      resourceType: resourceType,
      resourceId: resourceId,
    );
  }

  ConflictFailure changeToConflictFailure({
    String? traceId,
    String? code,
    Map<String, Object?>? localPatchWire,
    Map<String, Object?>? remotePatchWire,
  }) {
    return ConflictFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      localPatchWire: localPatchWire,
      remotePatchWire: remotePatchWire,
    );
  }

  CancelledFailure changeToCancelledFailure({String? traceId, String? code}) {
    return CancelledFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
    );
  }

  InterruptedFailure changeToInterruptedFailure({
    String? traceId,
    String? code,
    String? intentDigest,
  }) {
    return InterruptedFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      intentDigest: intentDigest,
    );
  }

  StorageFailure changeToStorageFailure({
    String? traceId,
    String? code,
    required String layer,
  }) {
    return StorageFailure.fromTrusted(
      message: message,
      traceId: traceId ?? this.traceId,
      isRetryable: isRetryable,
      code: code ?? this.code,
      layer: layer,
    );
  }
}
