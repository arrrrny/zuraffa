// Spec 1653-trim-heavy-deps (issue #1661): moved from the core package
// (lib/src/core/artifact_publisher.dart) — the MinIO artifact hook rides
// the storage companion; see the core CHANGELOG migration map.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:zuraffa/zuraffa.dart';

import 'minio_client.dart';

// ---------------------------------------------------------------------------
// MinIO Artifact Hook
// ---------------------------------------------------------------------------

/// Artifact hook that uploads artifacts to MinIO/S3-compatible storage.
///
/// Handles all data types:
/// - **Strings** (HTML, JSON, text) via [MinioClient.putObject]
/// - **Binary** ([Uint8List]) data (images, PDFs) via [MinioClient.putObjectBytes]
///
/// ## Object Key Structure
///
/// Keys are **reason-first** so browsing MinIO is intuitive — group by
/// *what happened* (failure, scan, debug), then *where* (source), then
/// *what kind* (label), with the entity ID as the filename:
///
/// ```
/// {pathPrefix}{reason}/{source}/{label}/{id}.{extension}
/// ```
///
/// Examples:
/// ```
/// prod/failure/network_client/request_failed/01923456-7890-abcd.html
/// prod/scan/image_capture/product_photo/01923456-7890-abcd.jpg
/// staging/debug/checkpoint_tool/workflow_step/01923456-7890-abcd.png
/// ```
///
/// ## Looking up artifacts later
///
/// ```dart
/// // List ALL failures across the app
/// client.listObjects(bucket: 'artifacts', prefix: 'prod/failure/');
///
/// // List failures from a specific source
/// client.listObjects(bucket: 'artifacts', prefix: 'prod/failure/network_client/');
///
/// // Direct GET — you know the exact key (reason + source + label + id)
/// client.getObject('artifacts',
///   'prod/failure/network_client/request_failed/01923456-7890-abcd.html');
/// ```
///
/// ## S3 Metadata Enrichment
///
/// Each upload includes custom `x-amz-meta-*` headers:
/// - `artifact-reason`: The [ArtifactContext.reason] string
/// - `artifact-source`: The [ArtifactContext.source]
/// - `artifact-label`: The [ArtifactContext.label] (if set)
/// - Plus all values from [ArtifactContext.metadata]
///
/// ## Registration
///
/// ```dart
/// // Option A: Injected client (recommended for DI / testing)
/// ArtifactPublisher.instance.register(MinIOArtifactHook(
///   client: MinioClient(
///     endpoint: 'http://localhost:9000',
///     accessKey: 'minioadmin',
///     secretKey: 'minioadmin',
///   ),
///   bucket: 'artifacts',
/// ));
///
/// // Option B: Convenience factory
/// ArtifactPublisher.instance.register(MinIOArtifactHook.fromParams(
///   endpoint: 'http://localhost:9000',
///   accessKey: 'minioadmin',
///   secretKey: 'minioadmin',
///   bucket: 'artifacts',
///   pathPrefix: 'prod/',
/// ));
/// ```
class MinIOArtifactHook extends ArtifactHook {
  /// The MinIO client used for uploads.
  final MinioClient client;

  /// The bucket to upload artifacts into.
  final String bucket;

  /// Whether to create the bucket if it doesn't exist on first upload.
  ///
  /// Defaults to `false`.
  final bool ensureBucketExists;

  /// Optional path prefix prepended to every object key.
  ///
  /// Useful for organising by environment, e.g. `'prod/'` or `'staging/'`.
  final String? pathPrefix;

  /// Whether to include [ArtifactContext.reason] as a key segment.
  ///
  /// Defaults to `true`. Set to `false` for a flatter key structure.
  final bool includeReasonInKey;

  /// Whether to include [ArtifactContext.source] as a key segment.
  ///
  /// Defaults to `true`.
  final bool includeSourceInKey;

  /// Custom extension overrides per content type.
  ///
  /// Keys are content type prefixes (e.g. `'image/'`) or exact matches
  /// (e.g. `'text/html'`). Values are the file extension without dot
  /// (e.g. `'jpg'`, `'html'`).
  ///
  /// Built-in defaults:
  /// ```
  /// 'text/html'          → 'html'
  /// 'application/json'   → 'json'
  /// 'text/plain'         → 'txt'
  /// 'image/jpeg'         → 'jpg'
  /// 'image/png'          → 'png'
  /// 'image/webp'         → 'webp'
  /// 'application/pdf'    → 'pdf'
  /// 'application/octet-stream' → 'bin'
  /// ```
  final Map<String, String> extensionOverrides;

  bool _bucketEnsured = false;

  @override
  String get id => 'minio-artifact';

  @override
  int get priority => 100;

  /// Creates a hook with a pre-built [client].
  MinIOArtifactHook({
    required this.client,
    required this.bucket,
    this.ensureBucketExists = false,
    this.pathPrefix,
    this.includeReasonInKey = true,
    this.includeSourceInKey = true,
    this.extensionOverrides = const {},
  });

  /// Convenience factory that creates a [MinioClient] from endpoint params.
  factory MinIOArtifactHook.fromParams({
    required String endpoint,
    required String accessKey,
    required String secretKey,
    required String bucket,
    String region = 'us-east-1',
    bool ensureBucketExists = false,
    String? pathPrefix,
    bool includeReasonInKey = true,
    bool includeSourceInKey = true,
    Map<String, String> extensionOverrides = const {},
  }) {
    return MinIOArtifactHook(
      client: MinioClient(
        endpoint: endpoint,
        accessKey: accessKey,
        secretKey: secretKey,
        region: region,
      ),
      bucket: bucket,
      ensureBucketExists: ensureBucketExists,
      pathPrefix: pathPrefix,
      includeReasonInKey: includeReasonInKey,
      includeSourceInKey: includeSourceInKey,
      extensionOverrides: extensionOverrides,
    );
  }

  @override
  Future<void> onPublish(ArtifactContext context) async {
    // Ensure bucket exists on first upload
    if (ensureBucketExists && !_bucketEnsured) {
      final ok = await client.ensureBucket(bucket);
      if (!ok) {
        _logger.severe(
          'MinIOArtifactHook: Could not create/access bucket "$bucket" — '
          'skipping upload',
        );
        return;
      }
      _bucketEnsured = true;
    }

    final key = _buildKey(context);
    final ext = _extensionFor(context);
    final fullKey = ext != null ? '$key.$ext' : key;

    // Build S3 metadata headers from context. Values must be safe for
    // HTTP headers, so keys are normalized and long/non-ASCII values are
    // compacted into ASCII-safe summaries.
    final s3Metadata = _buildS3Metadata(context);

    _logger.info(
      'Uploading artifact to MinIO: bucket=$bucket, key=$fullKey, '
      '${_dataSizeOf(context)}, reason=${context.reason}',
    );

    final bool success;
    if (context.isBinary) {
      success = await client.putObjectBytes(
        bucket: bucket,
        key: fullKey,
        bytes: context.dataAsBytes!,
        contentType: context.contentType,
        metadata: s3Metadata,
      );
    } else {
      success = await client.putObject(
        bucket: bucket,
        key: fullKey,
        data: context.data.toString(),
        contentType: context.contentType,
        metadata: s3Metadata,
      );
    }

    if (success) {
      _logger.info('Upload succeeded: $bucket/$fullKey');
    } else {
      _logger.warning('Upload failed: $bucket/$fullKey');
    }
  }

  static const int _maxMetadataValueLength = 512;
  static const int _metadataPreviewLength = 160;

  Map<String, String> _buildS3Metadata(ArtifactContext context) {
    final s3Metadata = <String, String>{};

    void put(String key, String value) {
      final sanitizedKey = _sanitizeMetadataKey(key);
      if (sanitizedKey.isEmpty) return;
      s3Metadata[sanitizedKey] = _sanitizeMetadataValue(value);
    }

    put('artifact-reason', context.reason);
    if (context.source != null) put('artifact-source', context.source!);
    if (context.label != null) put('artifact-label', context.label!);

    if (context.traceId != null) put('trace-id', context.traceId!);
    if (context.spanId != null) put('span-id', context.spanId!);

    for (final entry in context.metadata.entries) {
      put('ctx-${entry.key}', entry.value.toString());
    }

    return s3Metadata;
  }

  static String _sanitizeMetadataKey(String key) {
    final trimmed = key.trim().toLowerCase();
    if (trimmed.isEmpty) return '';

    final result = <int>[];
    var previousWasDash = false;

    for (final rune in trimmed.runes) {
      final isLowercaseLetter = rune >= 97 && rune <= 122;
      final isDigit = rune >= 48 && rune <= 57;
      final isDash = rune == 45;

      if (isLowercaseLetter || isDigit) {
        result.add(rune);
        previousWasDash = false;
      } else if (isDash || !previousWasDash) {
        result.add(45); // '-'
        previousWasDash = true;
      }
    }

    return String.fromCharCodes(result).replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static String _sanitizeMetadataValue(String value) {
    final normalized = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (normalized.isEmpty) return '';

    if (_isSafeHeaderValue(normalized) &&
        normalized.length <= _maxMetadataValueLength) {
      return normalized;
    }

    final preview = _headerPreview(normalized);
    return '[sanitized len=${normalized.length}] $preview';
  }

  static bool _isSafeHeaderValue(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit < 32 || codeUnit > 126) {
        return false;
      }
    }
    return true;
  }

  static String _headerPreview(String value) {
    final result = <String>[];
    var previousWasSpace = false;

    for (final codeUnit in value.codeUnits) {
      String char;
      if (codeUnit == 13 || codeUnit == 10 || codeUnit == 9) {
        char = ' ';
      } else if (codeUnit >= 32 && codeUnit <= 126) {
        char = String.fromCharCode(codeUnit);
      } else {
        char = '?';
      }

      if (char == ' ') {
        if (previousWasSpace) continue;
        previousWasSpace = true;
      } else {
        previousWasSpace = false;
      }

      result.add(char);
      if (result.length >= _metadataPreviewLength) {
        break;
      }
    }

    final preview = result.join().trim();
    if (value.length > _metadataPreviewLength) {
      return '$preview...';
    }
    return preview;
  }

  /// Build the S3 object key for this artifact.
  ///
  /// Reason-first pattern: `{pathPrefix}{reason}/{source}/{label}/{id}`
  ///
  /// This makes MinIO browsing intuitive — you see failures grouped
  /// together, then drill down by source, then by label, with the entity
  /// ID as the final filename:
  /// ```
  /// prod/failure/network_client/request_failed/01923456-7890-abcd.html
  /// ```
  String _buildKey(ArtifactContext context) {
    final parts = <String>[];

    // Optional environment prefix
    if (pathPrefix != null) {
      parts.add(pathPrefix!.endsWith('/') ? pathPrefix! : '$pathPrefix/');
    }

    // Reason folder first — group by what happened (failure, scan, debug)
    if (includeReasonInKey) {
      parts.add('${context.reason}/');
    }

    // Source subfolder — who produced this artifact
    if (includeSourceInKey && context.source != null) {
      parts.add('${_toFolderName(context.source!)}/');
    }

    // Label subfolder — what kind of artifact
    parts.add('${_toFolderName(context.label ?? 'artifact')}/');

    // Client-supplied path segments — allows consuming apps to inject
    // arbitrary folder hierarchy (e.g. region code, tier slug)
    for (final segment in context.pathSegments) {
      if (segment.isNotEmpty) {
        parts.add('${segment.toLowerCase()}/');
      }
    }

    // Entity ID as filename — the lookup key
    parts.add(context.id);

    return parts.join();
  }

  /// Convert a PascalCase or camelCase string to a snake_case folder name.
  ///
  /// `'NetworkClient'` → `'network_client'`
  /// `'RequestFailed'` → `'request_failed'`
  /// `'product_scan'` → `'product_scan'`
  static String _toFolderName(String input) {
    final result = <String>[];
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (i > 0 && char.toUpperCase() == char && char.toLowerCase() != char) {
        result.add('_');
      }
      result.add(char.toLowerCase());
    }
    return result.join();
  }

  /// Determine the file extension for the given content type.
  String? _extensionFor(ArtifactContext context) {
    final ct = context.contentType.split(';').first.trim().toLowerCase();

    // Check user overrides first (exact match, then prefix match)
    if (extensionOverrides.containsKey(ct)) return extensionOverrides[ct];
    for (final entry in extensionOverrides.entries) {
      if (ct.startsWith(entry.key)) return entry.value;
    }

    // Built-in defaults
    return switch (ct) {
      'text/html' => 'html',
      'application/json' => 'json',
      'text/plain' => 'txt',
      'text/xml' => 'xml',
      'application/xml' => 'xml',
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'image/svg+xml' => 'svg',
      'application/pdf' => 'pdf',
      'application/octet-stream' => 'bin',
      _ when ct.startsWith('image/') => 'img',
      _ when ct.startsWith('text/') => 'txt',
      _ => 'bin',
    };
  }

  static final Logger _logger = Logger('MinIOArtifactHook');
}

/// File-private replacement for the private `ArtifactContext._dataSize`
/// helper the hook used when it lived beside `ArtifactContext` in core
/// (spec 1653: the hook moved to the storage companion; the context's
/// private helpers do not travel).
String _dataSizeOf(ArtifactContext context) {
  final data = context.data;
  if (data is String) return '${data.length} chars';
  if (data is Uint8List) return '${data.length} bytes';
  return '?';
}
