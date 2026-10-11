// Spec 1653-trim-heavy-deps (issue #1661): moved from the core package
// (lib/src/core/failure_hooks.dart) — the MinIO upload hook rides the
// storage companion; see the core CHANGELOG migration map.
library;

import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

import 'minio_artifact_hook.dart';
import 'minio_client.dart';

/// @deprecated Use [MinIOArtifactHook] instead.
///
/// Backward-compatible alias for [MinIOArtifactHook].
///
/// Accepts the old-style constructor params and creates a
/// [MinIOArtifactHook] under the hood.
class MinIOUploadHook extends ArtifactHook {
  final MinIOArtifactHook _delegate;

  /// The MinIO client used for uploads.
  final MinioClient client;

  /// The bucket to upload failure artifacts into.
  final String bucket;

  MinIOUploadHook({
    required this.client,
    required this.bucket,
    bool ensureBucketExists = false,
    String? pathPrefix,
    String htmlContentType = 'text/html; charset=utf-8',
  }) : _delegate = MinIOArtifactHook(
         client: client,
         bucket: bucket,
         ensureBucketExists: ensureBucketExists,
         pathPrefix: pathPrefix,
       );

  /// Convenience factory that creates a [MinioClient] from endpoint params.
  factory MinIOUploadHook.fromParams({
    required String endpoint,
    required String accessKey,
    required String secretKey,
    required String bucket,
    String region = 'us-east-1',
    bool ensureBucketExists = false,
    String? pathPrefix,
    String htmlContentType = 'text/html; charset=utf-8',
  }) {
    return MinIOUploadHook(
      client: MinioClient(
        endpoint: endpoint,
        accessKey: accessKey,
        secretKey: secretKey,
        region: region,
      ),
      bucket: bucket,
      ensureBucketExists: ensureBucketExists,
      pathPrefix: pathPrefix,
    );
  }

  @override
  String get id => _delegate.id;

  @override
  int get priority => _delegate.priority;

  @override
  bool shouldPublish(ArtifactContext context) =>
      _delegate.shouldPublish(context);

  @override
  Future<void> onPublish(ArtifactContext context) =>
      _delegate.onPublish(context);
}
