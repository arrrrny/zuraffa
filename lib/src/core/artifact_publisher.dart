import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'minio_client.dart';

// ---------------------------------------------------------------------------
// Artifact Reason
// ---------------------------------------------------------------------------

/// Why an artifact is being published.
///
/// Hooks can filter on [ArtifactReason] to decide whether to act.
/// For example, a MinIO upload hook might handle all reasons,
/// while a notification hook only cares about [failure].
enum ArtifactReason {
  /// Published because a task failed (scrape, parse, network, etc.).
  ///
  /// The [ArtifactContext.data] is typically the HTML/text that was being
  /// processed when the failure occurred.
  failure,

  /// Published as the result of a scan (barcode, product image, etc.).
  ///
  /// The [ArtifactContext.data] is typically an image ([Uint8List]) or
  /// structured scan result.
  scan,

  /// Published for debugging or inspection purposes.
  ///
  /// For example, a snapshot of the current page state, or a screenshot
  /// captured during a critical workflow step.
  debug,

  /// Custom / user-defined reason.
  ///
  /// Use this for any scenario not covered by the built-in reasons.
  /// Provide a descriptive [ArtifactContext.label] to identify the purpose.
  custom,
}

// ---------------------------------------------------------------------------
// Artifact Context
// ---------------------------------------------------------------------------

/// Rich context passed to every [ArtifactHook] when an artifact is published.
///
/// Contains everything a hook needs to decide whether to act and how:
/// - [data] — the artifact payload (String for HTML/JSON, [Uint8List] for images)
/// - [contentType] — MIME type describing the payload
/// - [reason] — why this artifact is being published
/// - [source] — which component published it (e.g. `'ParsingProvider'`)
/// - [metadata] — arbitrary key-value pairs (task ID, URL, status code, etc.)
/// - [timestamp] — when the artifact was captured
/// - [stackTrace] — optional, set when [reason] is [ArtifactReason.failure]
/// - [label] — optional human-readable label (used as folder/key segment)
class ArtifactContext {
  /// Business entity ID that this artifact belongs to.
  ///
  /// This becomes the **filename** in MinIO — the ID you use to
  /// look up artifacts later. Typically the task/entity ID from your domain:
  /// - `Zik.id` (UUID v7) for scrape tasks
  /// - `ScrapeTask.id` for scrape results
  /// - A barcode string for product scans
  ///
  /// With fire-and-forget publishing, the app owns this ID upfront.
  /// MinIO keys are reason-first so browsing is intuitive:
  /// ```
  /// prod/failure/parsing_provider/failed/{id}.html
  /// prod/scan/barcode_scanner/product_photo/{id}.jpg
  /// ```
  final String id;

  /// The artifact payload.
  ///
  /// Common types:
  /// - `String` for HTML, JSON, plain text
  /// - [Uint8List] for images (JPEG, PNG), binary data
  /// - `Map<String, dynamic>` for structured data
  final dynamic data;

  /// MIME type describing [data].
  ///
  /// Examples: `text/html`, `image/jpeg`, `application/json`,
  /// `application/octet-stream`.
  final String contentType;

  /// Why this artifact is being published.
  final ArtifactReason reason;

  /// The component that published this artifact.
  ///
  /// For example: `'ParsingProvider'`, `'BarcodeScanner'`, `'ScrapeTask'`.
  final String? source;

  /// Arbitrary key-value pairs for enrichment.
  ///
  /// Common keys:
  /// - `'taskId'` — the task or job identifier
  /// - `'url'` — the URL being processed
  /// - `'statusCode'` — HTTP status code
  /// - `'error'` — error message (for failures)
  final Map<String, dynamic> metadata;

  /// When this artifact was captured.
  final DateTime timestamp;

  /// Stack trace from where the artifact originated.
  ///
  /// Only set when [reason] is [ArtifactReason.failure].
  final StackTrace? stackTrace;

  /// Optional human-readable label for this artifact.
  ///
  /// Used by hooks to build storage keys, filenames, or log messages.
  /// For example: `'NetworkFailure'`, `'barcode_scan'`, `'screenshot'`.
  final String? label;

  /// Creates a new artifact context.
  ///
  /// [id] is required — it's the business entity ID you'll use to look up
  /// this artifact later. Pass your task/entity ID (e.g. `Zik.id`).
  ArtifactContext({
    required this.id,
    required this.data,
    required this.contentType,
    required this.reason,
    this.source,
    this.metadata = const {},
    DateTime? timestamp,
    this.stackTrace,
    this.label,
  }) : timestamp = timestamp ?? DateTime.now();

  // --- Convenience getters ---

  /// Whether this artifact was published due to a failure.
  bool get isFailure => reason == ArtifactReason.failure;

  /// Whether this artifact was published from a scan.
  bool get isScan => reason == ArtifactReason.scan;

  /// Whether [data] is a String (HTML, JSON, text).
  bool get isText => data is String;

  /// Whether [data] is binary ([Uint8List]).
  bool get isBinary => data is Uint8List;

  /// Whether [contentType] indicates HTML.
  bool get isHtml => contentType.contains('html');

  /// Whether [contentType] indicates an image.
  bool get isImage => contentType.startsWith('image/');

  /// Access metadata with type safety.
  T? get<T>(String key) => metadata[key] as T?;

  /// The data as a [String]. Returns `null` if [data] is not a String.
  String? get dataAsString => data is String ? data as String : null;

  /// The data as [Uint8List]. Returns `null` if [data] is not [Uint8List].
  Uint8List? get dataAsBytes => data is Uint8List ? data as Uint8List : null;

  @override
  String toString() =>
      'ArtifactContext(id: $id, reason: ${reason.name}, contentType: $contentType, '
      'source: $source, label: $label, dataSize: ${_dataSize()})';

  String _dataSize() {
    if (data is String) return '${(data as String).length} chars';
    if (data is Uint8List) return '${(data as Uint8List).length} bytes';
    return '?';
  }
}

// ---------------------------------------------------------------------------
// Artifact Hook
// ---------------------------------------------------------------------------

/// Base class for artifact hooks.
///
/// Extend this to create custom hooks that react when artifacts are published.
/// Register hooks with [ArtifactPublisher.instance] to activate them.
///
/// ## Built-in Hook
///
/// [MinIOArtifactHook] — uploads artifacts to MinIO/S3 storage.
///
/// ## Custom Hook Example
///
/// ```dart
/// class SlackNotificationHook extends ArtifactHook {
///   @override
///   String get id => 'slack-notification';
///
///   @override
///   bool shouldPublish(ArtifactContext context) => context.isFailure;
///
///   @override
///   Future<void> onPublish(ArtifactContext context) async {
///     await slackClient.send(
///       channel: '#scrape-errors',
///       text: 'Artifact from ${context.source}: ${context.label}',
///     );
///   }
/// }
/// ```
abstract class ArtifactHook {
  /// Unique identifier for this hook.
  String get id;

  /// Priority order for execution (lower runs first).
  ///
  /// Defaults to `0`. Use higher values for hooks that depend on
  /// side-effects of earlier hooks.
  int get priority => 0;

  /// Whether this hook should handle the given [context].
  ///
  /// Override to filter which artifacts your hook processes.
  /// Default implementation handles all artifacts.
  bool shouldPublish(ArtifactContext context) => true;

  /// The hook's execution logic.
  ///
  /// Called when an artifact is published and [shouldPublish] returns `true`.
  ///
  /// **Important**: This method should be resilient and never throw.
  /// Exceptions are caught and logged by [ArtifactPublisher] but won't stop
  /// other hooks from running.
  Future<void> onPublish(ArtifactContext context);

  @override
  String toString() => 'ArtifactHook($id, priority: $priority)';
}

// ---------------------------------------------------------------------------
// Artifact Publisher
// ---------------------------------------------------------------------------

/// Global singleton manager for artifact hooks.
///
/// Responsible for:
/// - Registering and unregistering hooks
/// - Publishing artifacts to all applicable hooks
/// - Running hooks in priority order (low to high)
/// - Catching and logging hook errors to prevent cascading failures
///
/// ## Usage
///
/// ```dart
/// // Register a hook at app startup
/// ArtifactPublisher.instance.register(MinIOArtifactHook(
///   client: MinioClient(
///     endpoint: 'http://localhost:9000',
///     accessKey: 'minioadmin',
///     secretKey: 'minioadmin',
///   ),
///   bucket: 'artifacts',
/// ));
///
/// // Publish an artifact (fire-and-forget)
/// ArtifactPublisher.instance.publishFireAndForget(
///   data: rawHtml,
///   contentType: 'text/html; charset=utf-8',
///   reason: ArtifactReason.failure,
///   source: 'ParsingProvider',
///   label: 'NetworkFailure',
///   metadata: {'taskId': 'abc-123', 'url': 'https://example.com'},
/// );
///
/// // Publish an image (awaited)
/// await ArtifactPublisher.instance.publish(
///   data: imageBytes,
///   contentType: 'image/jpeg',
///   reason: ArtifactReason.scan,
///   source: 'BarcodeScanner',
///   label: 'product_scan',
///   metadata: {'barcode': '1234567890'},
/// );
/// ```
class ArtifactPublisher {
  static final ArtifactPublisher _instance = ArtifactPublisher._();
  factory ArtifactPublisher() => _instance;

  /// Convenience getter for the singleton instance.
  static ArtifactPublisher get instance => _instance;

  ArtifactPublisher._();

  static final Logger _logger = Logger('ArtifactPublisher');
  final List<ArtifactHook> _hooks = [];
  bool _isDisposed = false;

  /// The registered hooks (read-only, sorted by priority).
  List<ArtifactHook> get hooks => List.unmodifiable(_hooks);

  /// Register a new hook.
  ///
  /// If a hook with the same [ArtifactHook.id] already exists, it is replaced.
  void register(ArtifactHook hook) {
    if (_isDisposed) {
      _logger.warning('Cannot register hook after dispose: ${hook.id}');
      return;
    }
    unregister(hook.id);
    _hooks.add(hook);
    _hooks.sort((a, b) => a.priority.compareTo(b.priority));
    _logger.fine(
      'Registered artifact hook: ${hook.id} (priority: ${hook.priority})',
    );
  }

  /// Unregister a hook by [id].
  void unregister(String id) {
    final existed = _hooks.any((h) => h.id == id);
    _hooks.removeWhere((h) => h.id == id);
    if (existed) _logger.fine('Unregistered artifact hook: $id');
  }

  /// Unregister all hooks.
  void clear() {
    _hooks.clear();
    _logger.fine('Cleared all artifact hooks');
  }

  /// Publish an artifact to all applicable hooks (awaited).
  ///
  /// Hooks run in priority order. Each hook's [ArtifactHook.shouldPublish]
  /// is checked before calling [ArtifactHook.onPublish].
  ///
  /// This method never throws — hook errors are caught and logged individually.
  Future<void> publish(
    dynamic data, {
    required String id,
    required String contentType,
    required ArtifactReason reason,
    String? source,
    String? label,
    Map<String, dynamic> metadata = const {},
    StackTrace? stackTrace,
  }) async {
    if (_isDisposed) {
      _logger.warning('Ignoring publish after dispose');
      return;
    }

    final context = ArtifactContext(
      id: id,
      data: data,
      contentType: contentType,
      reason: reason,
      source: source,
      label: label,
      metadata: metadata,
      stackTrace: stackTrace,
    );

    final applicable = _hooks.where((h) => h.shouldPublish(context));

    if (applicable.isEmpty) return;

    _logger.info(
      'Publishing artifact id=$id (${context._dataSize()}, '
      'reason: ${reason.name}, contentType: $contentType) '
      'to ${applicable.length} hook(s) [source: $source, label: $label]',
    );

    for (final hook in applicable) {
      try {
        await hook.onPublish(context);
        _logger.fine('Hook completed: ${hook.id}');
      } catch (e, st) {
        _logger.severe('Hook failed: ${hook.id}', e, st);
        // Continue — one hook failure must not block others
      }
    }
  }

  /// Fire-and-forget version of [publish].
  ///
  /// Returns immediately without waiting for hooks to complete.
  void publishFireAndForget(
    dynamic data, {
    required String id,
    required String contentType,
    required ArtifactReason reason,
    String? source,
    String? label,
    Map<String, dynamic> metadata = const {},
    StackTrace? stackTrace,
  }) {
    unawaited(
      publish(
        data,
        id: id,
        contentType: contentType,
        reason: reason,
        source: source,
        label: label,
        metadata: metadata,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Dispose the publisher and clear all hooks.
  ///
  /// After calling this, no hooks can be registered and publish calls
  /// are ignored.
  void dispose() {
    _isDisposed = true;
    clear();
    _logger.info('ArtifactPublisher disposed');
  }
}

// ---------------------------------------------------------------------------
// MinIO Artifact Hook
// ---------------------------------------------------------------------------

/// Artifact hook that uploads artifacts to MinIO/S3-compatible storage.
///
/// Handles all data types:
/// - **Strings** (HTML, JSON, text) via [MinioClient.putObject]
/// - **Binary** ([Uint8List]) data (images, PDFs) via [MinioClient.putObjectBytes]
///
/// Object Key Structure
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
/// prod/failure/parsing_provider/failed/01923456-7890-abcd.html
/// prod/scan/barcode_scanner/product_photo/01923456-7890-abcd.jpg
/// staging/debug/screenshot_tool/checkout_step/01923456-7890-abcd.png
/// ```
///
/// ## Looking up artifacts later
///
/// ```dart
/// // List ALL failures across the app
/// client.listObjects(bucket: 'artifacts', prefix: 'prod/failure/');
///
/// // List failures from a specific source
/// client.listObjects(bucket: 'artifacts', prefix: 'prod/failure/parsing_provider/');
///
/// // Direct GET — you know the exact key (reason + source + label + id)
/// client.getObject('artifacts',
///   'prod/failure/parsing_provider/failed/01923456-7890-abcd.html');
/// ```
///
/// ## S3 Metadata Enrichment
///
/// Each upload includes custom `x-amz-meta-*` headers:
/// - `artifact-reason`: The [ArtifactReason] name
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
  /// Defaults to `true`.
  final bool ensureBucketExists;

  /// Optional path prefix prepended to every object key.
  ///
  /// Useful for organising by environment, e.g. `'prod/'` or `'staging/'`.
  final String? pathPrefix;

  /// Whether to include [ArtifactReason] as a key segment.
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
    this.ensureBucketExists = true,
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
    bool ensureBucketExists = true,
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

    // Build S3 metadata headers from context
    final s3Metadata = <String, String>{'artifact-reason': context.reason.name};
    if (context.source != null) s3Metadata['artifact-source'] = context.source!;
    if (context.label != null) s3Metadata['artifact-label'] = context.label!;

    // Attach all stringifiable metadata values
    for (final entry in context.metadata.entries) {
      s3Metadata['ctx-${entry.key}'] = entry.value.toString();
    }

    _logger.info(
      'Uploading artifact to MinIO: bucket=$bucket, key=$fullKey, '
      '${context._dataSize()}, reason=${context.reason.name}',
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

  /// Build the S3 object key for this artifact.
  ///
  /// Reason-first pattern: `{pathPrefix}{reason}/{source}/{label}/{id}`
  ///
  /// This makes MinIO browsing intuitive — you see failures grouped
  /// together, then drill down by source, then by label, with the entity
  /// ID as the final filename:
  /// ```
  /// prod/failure/parsing_provider/failed/01923456-7890-abcd.html
  /// ```
  String _buildKey(ArtifactContext context) {
    final parts = <String>[];

    // Optional environment prefix
    if (pathPrefix != null) {
      parts.add(pathPrefix!.endsWith('/') ? pathPrefix! : '$pathPrefix/');
    }

    // Reason folder first — group by what happened (failure, scan, debug)
    if (includeReasonInKey) {
      parts.add('${context.reason.name}/');
    }

    // Source subfolder — who produced this artifact
    if (includeSourceInKey && context.source != null) {
      parts.add('${_toFolderName(context.source!)}/');
    }

    // Label subfolder — what kind of artifact
    parts.add('${_toFolderName(context.label ?? 'artifact')}/');

    // Entity ID as filename — the lookup key
    parts.add(context.id);

    return parts.join();
  }

  /// Convert a PascalCase or camelCase string to a snake_case folder name.
  ///
  /// `'ParsingProvider'` → `'parsing_provider'`
  /// `'ParsingFailed'` → `'parsing_failed'`
  /// `'barcode_scan'` → `'barcode_scan'`
  static String _toFolderName(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (i > 0 && char.toUpperCase() == char && char.toLowerCase() != char) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
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
