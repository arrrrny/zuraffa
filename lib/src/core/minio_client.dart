import 'dart:convert';

import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:minio/io.dart';
import 'package:minio/minio.dart' as official;

/// A lightweight S3-compatible client for MinIO operations.
///
/// This is a thin wrapper around the official `minio` package that provides
/// a simpler, Result-style API while preserving the same functionality.
///
/// ## Usage
///
/// ```dart
/// final client = MinioClient(
///   endpoint: 'https://minio.myapp.com',
///   accessKey: 'minioadmin',
///   secretKey: 'minioadmin',
///   region: 'us-east-1',
/// );
///
/// await client.putObject(
///   bucket: 'scrape-failures',
///   key: 'task-123/NetworkFailure_1719398400000.html',
///   data: '<html>...</html>',
///   contentType: 'text/html',
/// );
///
/// client.close();
/// ```
class MinioClient {
  static final Logger _logger = Logger('MinioClient');

  final official.Minio _delegate;

  /// Base endpoint URL (e.g. `http://localhost:9000`).
  final String endpoint;

  /// S3 access key (MinIO username).
  final String accessKey;

  /// S3 secret key (MinIO password).
  final String secretKey;

  /// AWS region string. MinIO defaults to `us-east-1`.
  final String region;

  /// Whether to use path-style addressing (`host/bucket/key`).
  ///
  /// MinIO always uses path-style, so this defaults to `true`.
  /// Set to `false` only if you are talking to AWS S3 virtual-hosted
  /// style buckets.
  final bool pathStyle;

  /// Creates a new MinIO client.
  ///
  /// - [endpoint] must include scheme and port, e.g. `http://localhost:9000`
  /// - [region] defaults to `us-east-1` which is MinIO's default
  /// - [pathStyle] defaults to `true` (required for MinIO)
  MinioClient({
    required this.endpoint,
    required this.accessKey,
    required this.secretKey,
    this.region = 'us-east-1',
    this.pathStyle = true,
  }) : _delegate = official.Minio(
         endPoint: _stripScheme(endpoint),
         accessKey: accessKey,
         secretKey: secretKey,
         region: region,
         useSSL: endpoint.startsWith('https'),
         pathStyle: pathStyle,
       );

  static String _stripScheme(String url) {
    return url.replaceFirst(RegExp(r'^https?://'), '');
  }

  // ---------------------------------------------------------------------------
  // Bucket operations
  // ---------------------------------------------------------------------------

  /// Check whether a bucket exists.
  ///
  /// Returns `true` if the bucket exists and is accessible.
  Future<bool> bucketExists(String bucket) async {
    try {
      return await _delegate.bucketExists(bucket);
    } catch (e, stackTrace) {
      _logger.severe('bucketExists failed for $bucket', e, stackTrace);
      return false;
    }
  }

  /// Create a bucket if it does not already exist.
  ///
  /// Returns `true` if the bucket was created or already exists.
  Future<bool> ensureBucket(String bucket) async {
    try {
      await _delegate.makeBucket(bucket, region);
      _logger.info('Bucket created: $bucket');
      return true;
    } catch (e) {
      // Bucket may already exist — treat as success
      _logger.fine('ensureBucket for $bucket: $e');
      return true;
    }
  }

  /// Remove an empty bucket.
  ///
  /// Returns `true` on success.
  Future<bool> removeBucket(String bucket) async {
    try {
      await _delegate.removeBucket(bucket);
      _logger.fine('Bucket removed: $bucket');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('removeBucket failed for $bucket', e, stackTrace);
      return false;
    }
  }

  /// Get the region of a bucket.
  ///
  /// Returns the region string (e.g. `us-east-1`), or `null` on failure.
  Future<String?> getBucketRegion(String bucket) async {
    try {
      return await _delegate.getBucketRegion(bucket);
    } catch (e, stackTrace) {
      _logger.severe('getBucketRegion failed for $bucket', e, stackTrace);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Object operations — string / bytes
  // ---------------------------------------------------------------------------

  /// Upload a string payload to [bucket]/[key].
  ///
  /// - [data] is the body to upload (e.g. HTML content).
  /// - [contentType] defaults to `application/octet-stream`.
  /// - [metadata] is optional custom headers (x-amz-meta-*).
  ///
  /// Returns `true` on success, `false` on failure (errors are logged).
  Future<bool> putObject({
    required String bucket,
    required String key,
    required String data,
    String contentType = 'application/octet-stream',
    Map<String, String>? metadata,
  }) async {
    try {
      _logger.fine('PUT $bucket/$key (${data.length} bytes)');
      final bytes = utf8.encode(data);
      await _delegate.putObject(
        bucket,
        key,
        Stream.value(Uint8List.fromList(bytes)),
        metadata: _withContentType(metadata, contentType),
      );
      _logger.fine('PUT succeeded: $bucket/$key');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('PUT failed for $bucket/$key', e, stackTrace);
      return false;
    }
  }

  /// Upload raw bytes to [bucket]/[key].
  ///
  /// Use this for binary data (images, compressed files, etc.).
  Future<bool> putObjectBytes({
    required String bucket,
    required String key,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
    Map<String, String>? metadata,
  }) async {
    try {
      _logger.fine('PUT bytes $bucket/$key (${bytes.length} bytes)');
      await _delegate.putObject(
        bucket,
        key,
        Stream.value(bytes),
        metadata: _withContentType(metadata, contentType),
      );
      _logger.fine('PUT bytes succeeded: $bucket/$key');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('PUT bytes failed for $bucket/$key', e, stackTrace);
      return false;
    }
  }

  /// Retrieve an object as a string.
  ///
  /// Returns `null` if the object does not exist or the request fails.
  Future<String?> getObject(String bucket, String key) async {
    try {
      final stream = await _delegate.getObject(bucket, key);
      final bytes = await stream.fold<Uint8List>(
        Uint8List(0),
        (prev, chunk) => Uint8List.fromList([...prev, ...chunk]),
      );
      return utf8.decode(bytes);
    } catch (e, stackTrace) {
      _logger.severe('GET failed for $bucket/$key', e, stackTrace);
      return null;
    }
  }

  /// Delete an object.
  ///
  /// Returns `true` on success (or if the object did not exist).
  Future<bool> deleteObject(String bucket, String key) async {
    try {
      await _delegate.removeObject(bucket, key);
      _logger.fine('DELETE succeeded: $bucket/$key');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('DELETE failed for $bucket/$key', e, stackTrace);
      return false;
    }
  }

  /// Delete multiple objects.
  ///
  /// Returns `true` if all deletions succeeded.
  Future<bool> deleteObjects(String bucket, List<String> keys) async {
    try {
      await _delegate.removeObjects(bucket, keys);
      _logger.fine('DELETE multiple succeeded: $bucket/${keys.length} objects');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('DELETE multiple failed for $bucket', e, stackTrace);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Object operations — file-based
  // ---------------------------------------------------------------------------

  /// Upload a local file to [bucket]/[key].
  ///
  /// Content-Type is auto-detected from the file extension.
  /// - [metadata] is optional custom headers (x-amz-meta-*).
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> fPutObject({
    required String bucket,
    required String key,
    required String filePath,
    Map<String, String>? metadata,
  }) async {
    try {
      _logger.fine('fPutObject $bucket/$key from $filePath');
      await _delegate.fPutObject(bucket, key, filePath, metadata: metadata);
      _logger.fine('fPutObject succeeded: $bucket/$key');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('fPutObject failed for $bucket/$key', e, stackTrace);
      return false;
    }
  }

  /// Download [bucket]/[key] and save it to [filePath].
  ///
  /// The parent directory is created automatically if needed.
  /// Returns `true` on success, `false` on failure.
  Future<bool> fGetObject({
    required String bucket,
    required String key,
    required String filePath,
  }) async {
    try {
      _logger.fine('fGetObject $bucket/$key to $filePath');
      await _delegate.fGetObject(bucket, key, filePath);
      _logger.fine('fGetObject succeeded: $bucket/$key -> $filePath');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('fGetObject failed for $bucket/$key', e, stackTrace);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Object metadata / copy
  // ---------------------------------------------------------------------------

  /// Get metadata/stat for an object.
  ///
  /// Returns `null` if the object does not exist or the request fails.
  Future<ObjectStat?> statObject(String bucket, String key) async {
    try {
      final stat = await _delegate.statObject(bucket, key);
      return ObjectStat(
        etag: stat.etag ?? '',
        size: stat.size ?? 0,
        lastModified: stat.lastModified,
        metadata: stat.metaData?.map((k, v) => MapEntry(k, v ?? '')) ?? {},
      );
    } catch (e, stackTrace) {
      _logger.severe('statObject failed for $bucket/$key', e, stackTrace);
      return null;
    }
  }

  /// Copy an object within the same or different bucket.
  ///
  /// - [srcBucket] / [srcKey] — source object
  /// - [destBucket] / [destKey] — destination object
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> copyObject({
    required String srcBucket,
    required String srcKey,
    required String destBucket,
    required String destKey,
  }) async {
    try {
      _logger.fine('copyObject $srcBucket/$srcKey -> $destBucket/$destKey');
      await _delegate.copyObject(destBucket, destKey, '$srcBucket/$srcKey');
      _logger.fine('copyObject succeeded');
      return true;
    } catch (e, stackTrace) {
      _logger.severe(
        'copyObject failed: $srcBucket/$srcKey -> $destBucket/$destKey',
        e,
        stackTrace,
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Listing
  // ---------------------------------------------------------------------------

  /// List objects in a bucket.
  ///
  /// - [bucket] — the bucket to list.
  /// - [prefix] — filter keys starting with this prefix.
  /// - [recursive] — whether to recurse into "directories" (default `false`).
  ///
  /// Returns a list of [ObjectInfo] on success, empty list on failure.
  Future<List<ObjectInfo>> listObjects(
    String bucket, {
    String? prefix,
    bool recursive = false,
  }) async {
    try {
      final results = <ObjectInfo>[];
      await for (final chunk in _delegate.listObjects(
        bucket,
        prefix: prefix ?? '',
        recursive: recursive,
      )) {
        for (final obj in chunk.objects) {
          results.add(
            ObjectInfo(
              key: obj.key ?? '',
              size: obj.size ?? 0,
              etag: obj.eTag ?? '',
              lastModified: obj.lastModified,
            ),
          );
        }
      }
      return results;
    } catch (e, stackTrace) {
      _logger.severe('listObjects failed for $bucket', e, stackTrace);
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Presigned URLs
  // ---------------------------------------------------------------------------

  /// Generate a presigned GET URL for an object.
  ///
  /// Returns a URL that can be used to access the object without credentials.
  /// - [expires] defaults to 7 days (604800 seconds).
  Future<String> presignedGetObject(
    String bucket,
    String key, {
    int expires = 604800,
  }) async {
    return await _delegate.presignedGetObject(bucket, key, expires: expires);
  }

  /// Generate a presigned PUT URL for uploading an object.
  ///
  /// The URL allows PUT uploads without credentials.
  /// - [expires] defaults to 7 days (604800 seconds).
  Future<String> presignedPutObject(
    String bucket,
    String key, {
    int expires = 604800,
  }) async {
    return await _delegate.presignedPutObject(bucket, key, expires: expires);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Close the client.
  ///
  /// No-op — kept for API compatibility. The official minio package
  /// manages its own HTTP client lifecycle.
  void close() {}

  Map<String, String> _withContentType(
    Map<String, String>? metadata,
    String contentType,
  ) {
    final map = <String, String>{};
    if (metadata != null) map.addAll(metadata);
    map['Content-Type'] = contentType;
    return map;
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// Metadata/stat result from [MinioClient.statObject].
class ObjectStat {
  final String etag;
  final int size;
  final DateTime? lastModified;
  final Map<String, String> metadata;

  const ObjectStat({
    required this.etag,
    required this.size,
    required this.lastModified,
    required this.metadata,
  });

  @override
  String toString() =>
      'ObjectStat(etag=$etag, size=$size, lastModified=$lastModified)';
}

/// Info about a listed object.
class ObjectInfo {
  final String key;
  final int size;
  final String etag;
  final DateTime? lastModified;

  const ObjectInfo({
    required this.key,
    required this.size,
    required this.etag,
    this.lastModified,
  });

  @override
  String toString() => 'ObjectInfo(key=$key, size=$size, etag=$etag)';
}
