import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

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

    if (report.failure.cause != null) {
      json['cause'] = report.failure.cause.toString();
    }

    // Preserve failure-specific fields for richer OTel spans
    json['failureData'] = _failureDataToJson(report.failure);

    return json;
  }

  Map<String, dynamic> _failureDataToJson(AppFailure failure) {
    return switch (failure) {
      ServerFailure(:final statusCode) => {
        if (statusCode != null) 'statusCode': statusCode,
      },
      NetworkFailure() => {},
      ValidationFailure(:final fieldErrors) => {
        if (fieldErrors != null) 'fieldErrors': fieldErrors,
      },
      NotFoundFailure(:final resourceType, :final resourceId) => {
        if (resourceType != null) 'resourceType': resourceType,
        if (resourceId != null) 'resourceId': resourceId,
      },
      UnauthorizedFailure() => {},
      ForbiddenFailure(:final requiredPermission) => {
        if (requiredPermission != null)
          'requiredPermission': requiredPermission,
      },
      TimeoutFailure(:final timeout) => {
        if (timeout != null) 'timeoutMs': timeout.inMilliseconds,
      },
      ConflictFailure(:final conflictType) => {
        if (conflictType != null) 'conflictType': conflictType,
      },
      CacheFailure() => {},
      PlatformFailure(:final code) => {if (code != null) 'code': code},
      CancellationFailure() => {},
      StateFailure() => {},
      TypeFailure() => {},
      UnimplementedFailure() => {},
      UnsupportedFailure() => {},
      UnknownFailure() => {},
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

  /// Reconstruct the most specific AppFailure subtype possible.
  AppFailure _reconstructFailure(
    String type,
    String message,
    Map<String, dynamic> data,
  ) {
    return switch (type) {
      'ServerFailure' => ServerFailure(
        message,
        statusCode: data['statusCode'] as int?,
      ),
      'NetworkFailure' => NetworkFailure(message),
      'ValidationFailure' => ValidationFailure(
        message,
        fieldErrors: _reconstructFieldErrors(data['fieldErrors']),
      ),
      'NotFoundFailure' => NotFoundFailure(
        message,
        resourceType: data['resourceType'] as String?,
        resourceId: data['resourceId'] as String?,
      ),
      'UnauthorizedFailure' => UnauthorizedFailure(message),
      'ForbiddenFailure' => ForbiddenFailure(
        message,
        requiredPermission: data['requiredPermission'] as String?,
      ),
      'TimeoutFailure' => TimeoutFailure(
        message,
        timeout: data['timeoutMs'] != null
            ? Duration(milliseconds: data['timeoutMs'] as int)
            : null,
      ),
      'ConflictFailure' => ConflictFailure(
        message,
        conflictType: data['conflictType'] as String?,
      ),
      'CacheFailure' => CacheFailure(message),
      'PlatformFailure' => PlatformFailure(
        message,
        code: data['code'] as String?,
      ),
      'CancellationFailure' => CancellationFailure(message),
      'StateFailure' => StateFailure(message),
      'TypeFailure' => TypeFailure(message),
      'UnimplementedFailure' => UnimplementedFailure(message),
      'UnsupportedFailure' => UnsupportedFailure(message),
      // Fallback — preserves the message even for unknown types
      _ => UnknownFailure(message),
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
}
