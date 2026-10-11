/// S3/MinIO storage capability for Zuraffa (optional companion package).
///
/// Spec 1653-trim-heavy-deps (issue #1661): MinioClient and the MinIO
/// artifact hooks moved out of the core package. See the core CHANGELOG
/// for the migration map.
library;

export 'src/minio_artifact_hook.dart';
export 'src/minio_client.dart';
export 'src/minio_upload_hook.dart';
