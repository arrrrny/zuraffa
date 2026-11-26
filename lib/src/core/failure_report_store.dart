import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'failure.dart';
import 'failure_reporter.dart';

/// Persists failure reports to a JSON file on disk.
///
/// Used by [FailureReportQueue] to survive app restarts:
/// - On flush failure → save un-exported reports to disk
/// - On next startup → load persisted reports and re-attempt flush
/// - On successful flush → clear the file
///
/// ## Storage Format
/// Reports are stored as a JSON array of maps. Each failure is serialized
/// with its runtime type and message, so OTel spans can be reconstructed
/// with full context even after deserialization.
///
/// ```json
/// [
///   {
///     "failureType": "ServerFailure",
///     "message": "Internal server error",
///     "timestamp": "2024-01-15T10:30:00.000Z",
///     "stackTrace": "#0 ...",
///     "attributes": {"usecase": "GetProductUseCase"},
///     "failureData": {"statusCode": 500}
///   }
/// ]
/// ```
class FailureReportStore {
  static final _logger = Logger('FailureReportStore');

  /// Path to the persistence file.
  final String filePath;

  FailureReportStore({required this.filePath});

  /// Save reports to disk. Overwrites any existing file.
  Future<void> save(List<FailureReport> reports) async {
    if (reports.isEmpty) {
      await clear();
      return;
    }

    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);

      final jsonList = reports.map(_reportToJson).toList();
      await file.writeAsString(jsonEncode(jsonList));

      _logger.fine('Persisted ${reports.length} failure reports to disk');
    } catch (e, stackTrace) {
      _logger.warning('Failed to persist failure reports', e, stackTrace);
    }
  }

  /// Load persisted reports from disk.
  ///
  /// Returns an empty list if the file doesn't exist or is corrupted.
  /// Clears the file after successful load.
  Future<List<FailureReport>> load() async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final jsonList = jsonDecode(content) as List<dynamic>;
      final reports = <FailureReport>[];

      for (final json in jsonList) {
        try {
          reports.add(_reportFromJson(json as Map<String, dynamic>));
        } catch (e) {
          _logger.warning('Skipping corrupted report entry: $e');
        }
      }

      // Clear after successful load — they're now in memory
      await clear();

      _logger.fine('Loaded ${reports.length} persisted failure reports');
      return reports;
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to load persisted failure reports',
        e,
        stackTrace,
      );
      // Don't leave a corrupted file around
      await clear();
      return [];
    }
  }

  /// Delete the persistence file.
  Future<void> clear() async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      _logger.warning('Failed to clear persistence file: $e');
    }
  }

  /// Whether there are persisted reports on disk.
  bool get hasPersisted {
    try {
      final file = File(filePath);
      return file.existsSync() && file.lengthSync() > 2; // > "[]"
    } catch (_) {
      return false;
    }
  }

  // ── Serialization ──────────────────────────────────────────────

  Map<String, dynamic> _reportToJson(FailureReport report) {
    final json = <String, dynamic>{
      'failureType': report.failure.runtimeType.toString(),
      'message': report.failure.message,
      'timestamp': report.timestamp.toIso8601String(),
    };

    if (report.stackTrace != null) {
      json['stackTrace'] = report.stackTrace.toString();
    }

    if (report.attributes != null && report.attributes!.isNotEmpty) {
      json['attributes'] = report.attributes;
    }

    // Preserve failure-specific fields for richer OTel spans
    json['failureData'] = _failureDataToJson(report.failure);

    return json;
  }

  /// Fields shared by every variant, persisted so replay does not change a
  /// report's retry semantics or correlation id after a restart.
  Map<String, dynamic> _sharedFailureData(AppFailure failure) {
    final data = <String, dynamic>{'isRetryable': failure.isRetryable};
    final traceId = failure.traceId;
    if (traceId != null) data['traceId'] = traceId;
    return data;
  }

  Map<String, dynamic> _failureDataToJson(AppFailure failure) {
    return switch (failure) {
      NetworkFailure(:final statusCode) => {
        ..._sharedFailureData(failure),
        'statusCode': ?statusCode,
      },
      TimeoutFailure(:final timeout) => {
        ..._sharedFailureData(failure),
        'timeoutMs': timeout?.inMilliseconds,
      },
      BoundaryViolationFailure(:final violations) => {
        ..._sharedFailureData(failure),
        'violations': [
          for (final v in violations)
            {'path': v.path, 'expected': v.expected, 'actual': v.actual},
        ],
      },
      PolicyDeniedFailure(:final reason) => {
        ..._sharedFailureData(failure),
        'reason': reason,
      },
      NotFoundFailure(:final resourceType, :final resourceId) => {
        ..._sharedFailureData(failure),
        'resourceType': resourceType,
        'resourceId': resourceId,
      },
      ConflictFailure(:final localPatchWire, :final remotePatchWire) => {
        ..._sharedFailureData(failure),
        'localPatchWire': localPatchWire,
        'remotePatchWire': remotePatchWire,
      },
      CancelledFailure() => _sharedFailureData(failure),
      InterruptedFailure(:final intentDigest) => {
        ..._sharedFailureData(failure),
        'intentDigest': intentDigest,
      },
      StorageFailure(:final layer) => {
        ..._sharedFailureData(failure),
        'layer': layer,
      },
      UnexpectedFailure(:final cause, :final stackTrace) => {
        ..._sharedFailureData(failure),
        'cause': ?cause,
        'stackTrace': ?stackTrace,
      },
    };
  }

  FailureReport _reportFromJson(Map<String, dynamic> json) {
    final failureType = json['failureType'] as String;
    final message = json['message'] as String;
    final data = json['failureData'] as Map<String, dynamic>? ?? {};

    final failure = _reconstructFailure(failureType, message, data);

    // Merge original type into attributes so OTel spans retain full context
    final attrs = <String, String>{};
    if (json['attributes'] != null) {
      final raw = json['attributes'] as Map<String, dynamic>;
      attrs.addAll(raw.map((k, v) => MapEntry(k, v.toString())));
    }
    attrs['failure.persisted'] = 'true';
    attrs['failure.original_type'] = failureType;

    return FailureReport(
      failure: failure,
      timestamp: DateTime.parse(json['timestamp'] as String),
      stackTrace: json['stackTrace'] != null
          ? StackTrace.fromString(json['stackTrace'] as String)
          : null,
      attributes: attrs,
    );
  }

  // Older records have none of the shared fields; fall back to the variant's
  // default there so replay matches the original construction semantics.
  bool _storedRetryable(Map<String, dynamic> data, {required bool fallback}) =>
      data['isRetryable'] as bool? ?? fallback;

  String? _storedTraceId(Map<String, dynamic> data) =>
      data['traceId'] as String?;

  StackTrace? _storedStackTrace(Map<String, dynamic> data) {
    final value = data['stackTrace'] as String?;
    return value == null ? null : StackTrace.fromString(value);
  }

  /// Reconstruct the most specific AppFailure subtype possible.
  AppFailure _reconstructFailure(
    String type,
    String message,
    Map<String, dynamic> data,
  ) {
    return switch (type) {
      // v8 variant type names (what the store persists).
      'NetworkFailure' => networkFailure(
        message,
        statusCode: data['statusCode'] as int?,
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'TimeoutFailure' => timeoutFailure(
        message,
        timeout: data['timeoutMs'] != null
            ? Duration(milliseconds: data['timeoutMs'] as int)
            : null,
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: true),
      ),
      'BoundaryViolationFailure' => boundaryViolationFailure(
        message,
        violations: _reconstructViolations(data['violations']),
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'PolicyDeniedFailure' => policyDeniedFailure(
        message,
        reason: (data['reason'] as String?) ?? 'permission',
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'NotFoundFailure' => notFoundFailure(
        message,
        resourceType: data['resourceType'] as String?,
        resourceId: data['resourceId'] as String?,
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'ConflictFailure' => conflictFailure(
        message,
        localPatchWire: (data['localPatchWire'] as Map?)
            ?.cast<String, Object?>(),
        remotePatchWire: (data['remotePatchWire'] as Map?)
            ?.cast<String, Object?>(),
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'CancelledFailure' => CancelledFailure.fromTrusted(
        message: message,
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'InterruptedFailure' => interruptedFailure(
        message,
        intentDigest: data['intentDigest'] as String?,
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: true),
      ),
      'StorageFailure' => storageFailure(
        message,
        layer: (data['layer'] as String?) ?? 'cache',
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'UnexpectedFailure' => unexpectedFailure(
        message,
        cause: data['cause'],
        stackTrace: _storedStackTrace(data),
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      // Legacy v2 type names (back-compat with already-persisted reports).
      'ServerFailure' => networkFailure(
        message,
        statusCode: data['statusCode'] as int?,
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'ValidationFailure' => boundaryViolationFailure(
        message,
        fieldErrors: _reconstructFieldErrors(data['fieldErrors']),
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      // A persisted 401 was an authentication failure in v2; keep that
      // distinction after reload instead of calling it generic "permission".
      'UnauthorizedFailure' => policyDeniedFailure(
        message,
        reason: 'unauthenticated',
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'ForbiddenFailure' => policyDeniedFailure(
        message,
        reason: 'forbidden',
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'CacheFailure' => storageFailure(
        message,
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'PlatformFailure' => unexpectedFailure(
        message,
        cause: data['cause'],
        stackTrace: _storedStackTrace(data),
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'CancellationFailure' => CancelledFailure.fromTrusted(
        message: message,
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'StateFailure' => unexpectedFailure(
        message,
        cause: data['cause'],
        stackTrace: _storedStackTrace(data),
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'TypeFailure' => unexpectedFailure(
        message,
        cause: data['cause'],
        stackTrace: _storedStackTrace(data),
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'UnimplementedFailure' => unexpectedFailure(
        message,
        cause: data['cause'],
        stackTrace: _storedStackTrace(data),
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'UnsupportedFailure' => unexpectedFailure(
        message,
        cause: data['cause'],
        stackTrace: _storedStackTrace(data),
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      'UnknownFailure' => unexpectedFailure(
        message,
        cause: data['cause'],
        stackTrace: _storedStackTrace(data),
        traceId: _storedTraceId(data),
        isRetryable: _storedRetryable(data, fallback: false),
      ),
      // Fallback — preserves the message even for unknown types
      _ => unexpectedFailure(message),
    };
  }

  Map<String, List<String>>? _reconstructFieldErrors(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      return raw.map((k, v) {
        if (v is List) {
          return MapEntry(k, v.map((e) => e.toString()).toList());
        }
        return MapEntry(k, [v.toString()]);
      });
    }
    return null;
  }

  List<FieldViolation> _reconstructViolations(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          FieldViolation(
            path: (item['path'] as String?) ?? '',
            expected: (item['expected'] as String?) ?? '',
            actual: (item['actual'] as String?) ?? '',
          ),
    ];
  }
}
