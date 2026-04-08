// ---------------------------------------------------------------------------
// Backward-compatibility layer — delegates to ArtifactPublisher.
//
// Prefer using ArtifactPublisher, ArtifactHook, and ArtifactContext directly.
// These classes are kept for existing code that depends on the failure-only API.
// ---------------------------------------------------------------------------

import 'artifact_publisher.dart';
import 'minio_client.dart';
import 'failure.dart';
import 'result.dart';

export 'artifact_publisher.dart'
    show ArtifactPublisher, ArtifactHook, ArtifactContext, MinIOArtifactHook;

/// @deprecated Use [ArtifactContext] directly.
///
/// Backward-compatible context that wraps a [FailureContext] into an
/// [ArtifactContext] with reason `'failure'`.
class FailureContext {
  /// The failure that occurred.
  final AppFailure failure;

  /// Stack trace from where the failure originated.
  final StackTrace stackTrace;

  /// Name of the UseCase that triggered this failure (if applicable).
  final String? useCaseName;

  /// Arbitrary metadata associated with this failure.
  final Map<String, dynamic> metadata;

  /// Optional path segments for artifact storage.
  final List<String> pathSegments;

  /// When this failure was captured.
  final DateTime timestamp;

  FailureContext({
    required this.failure,
    required this.stackTrace,
    this.useCaseName,
    this.metadata = const {},
    this.pathSegments = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convenience getter to check if this is a scraping-related failure.
  bool get isScrapingFailure => switch (failure) {
    NetworkFailure() => true,
    ServerFailure() => true,
    TimeoutFailure() => true,
    ValidationFailure() => true,
    _ => false,
  };

  /// Convenience getter to check if this is a cancellation.
  bool get isCancellation => failure is CancellationFailure;

  /// Access metadata with type safety.
  T? get<T>(String key) => metadata[key] as T?;

  /// Convert to an [ArtifactContext].
  ArtifactContext toArtifactContext() => ArtifactContext(
    id:
        metadata['taskId']?.toString() ??
        'failure_${timestamp.millisecondsSinceEpoch}',
    data: metadata['html'] ?? metadata['data'] ?? failure.message,
    contentType: 'text/html; charset=utf-8',
    reason: 'failure',
    source: useCaseName,
    label: failure.runtimeType.toString(),
    metadata: metadata,
    timestamp: timestamp,
    stackTrace: stackTrace,
    pathSegments: pathSegments,
  );

  @override
  String toString() =>
      'FailureContext(${failure.runtimeType}: ${failure.message}, '
      'useCase: $useCaseName, metadata: ${metadata.keys})';
}

/// @deprecated Extend [ArtifactHook] instead.
///
/// Backward-compatible base class for failure hooks.
/// Delegates to [ArtifactPublisher] under the hood.
abstract class FailureHook {
  /// Unique identifier for this hook.
  String get id;

  /// Priority order for execution (lower runs first).
  int get priority => 0;

  /// Whether this hook should be triggered for the given [context].
  bool shouldTrigger(FailureContext context) =>
      !context.isCancellation && context.failure is! UnknownFailure;

  /// The hook's execution logic.
  Future<void> onFailure(FailureContext context);

  @override
  String toString() => 'FailureHook($id, priority: $priority)';
}

/// @deprecated Use [ArtifactPublisher.instance] instead.
///
/// Backward-compatible singleton that delegates all operations to
/// [ArtifactPublisher].
///
/// When you call [register] with a [FailureHook], it creates an internal
/// [ArtifactHook] adapter and registers it with [ArtifactPublisher].
class FailureHookManager {
  static final FailureHookManager _instance = FailureHookManager._();
  factory FailureHookManager() => _instance;
  FailureHookManager._();

  final Map<String, _FailureHookAdapter> _adapters = {};

  /// The registered hooks (read-only).
  List<ArtifactHook> get hooks => ArtifactPublisher.instance.hooks;

  /// Register a [FailureHook].
  ///
  /// Creates an adapter and registers it with [ArtifactPublisher].
  void register(FailureHook hook) {
    final adapter = _FailureHookAdapter(hook);
    _adapters[hook.id] = adapter;
    ArtifactPublisher.instance.register(adapter);
  }

  /// Unregister a hook by [id].
  void unregister(String id) {
    _adapters.remove(id);
    ArtifactPublisher.instance.unregister(id);
  }

  /// Unregister all failure hooks (only those registered via this manager).
  void clear() {
    for (final id in _adapters.keys.toList()) {
      ArtifactPublisher.instance.unregister(id);
    }
    _adapters.clear();
  }

  /// Trigger hooks for a failure (awaited).
  ///
  /// Converts the failure info into an [ArtifactContext] with
  /// reason `'failure'` and publishes via [ArtifactPublisher].
  Future<void> trigger(
    AppFailure failure,
    StackTrace stackTrace, {
    String? useCaseName,
    Map<String, dynamic> metadata = const {},
    List<String> pathSegments = const [],
  }) async {
    final id =
        metadata['taskId']?.toString() ??
        'failure_${DateTime.now().millisecondsSinceEpoch}';
    await ArtifactPublisher.instance.publish(
      metadata['html'] ?? metadata['data'] ?? failure.message,
      id: id,
      contentType: 'text/html; charset=utf-8',
      reason: 'failure',
      source: useCaseName,
      label: failure.runtimeType.toString(),
      metadata: metadata,
      stackTrace: stackTrace,
      pathSegments: pathSegments,
    );
  }

  /// Fire-and-forget version of [trigger].
  void triggerFireAndForget(
    AppFailure failure,
    StackTrace stackTrace, {
    String? useCaseName,
    Map<String, dynamic> metadata = const {},
    List<String> pathSegments = const [],
  }) {
    final id =
        metadata['taskId']?.toString() ??
        'failure_${DateTime.now().millisecondsSinceEpoch}';
    ArtifactPublisher.instance.publishFireAndForget(
      metadata['html'] ?? metadata['data'] ?? failure.message,
      id: id,
      contentType: 'text/html; charset=utf-8',
      reason: 'failure',
      source: useCaseName,
      label: failure.runtimeType.toString(),
      metadata: metadata,
      stackTrace: stackTrace,
      pathSegments: pathSegments,
    );
  }

  /// Dispose the manager and clear all hooks.
  void dispose() {
    clear();
  }
}

/// Internal adapter that wraps a [FailureHook] as an [ArtifactHook].
class _FailureHookAdapter extends ArtifactHook {
  final FailureHook _wrapped;

  _FailureHookAdapter(this._wrapped);

  @override
  String get id => _wrapped.id;

  @override
  int get priority => _wrapped.priority;

  @override
  bool shouldPublish(ArtifactContext context) {
    if (context.reason != 'failure') return false;
    // Reconstruct a FailureContext for the wrapped hook
    final failure =
        context.metadata['failure'] as AppFailure? ??
        ValidationFailure(context.label ?? 'Unknown failure');
    final fc = FailureContext(
      failure: failure,
      stackTrace: context.stackTrace ?? StackTrace.current,
      useCaseName: context.source,
      metadata: context.metadata,
      timestamp: context.timestamp,
    );
    return _wrapped.shouldTrigger(fc);
  }

  @override
  Future<void> onPublish(ArtifactContext context) async {
    final failure =
        context.metadata['failure'] as AppFailure? ??
        ValidationFailure(context.label ?? 'Unknown failure');
    final fc = FailureContext(
      failure: failure,
      stackTrace: context.stackTrace ?? StackTrace.current,
      useCaseName: context.source,
      metadata: context.metadata,
      timestamp: context.timestamp,
    );
    await _wrapped.onFailure(fc);
  }
}

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
    bool ensureBucketExists = true,
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
    bool ensureBucketExists = true,
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

/// Extension on [Result] for triggering failure hooks on failure.
///
/// @deprecated Use [ArtifactPublisher] directly with your own failure handling.
extension ResultFailureHooks<S, F extends AppFailure> on Result<S, F> {
  /// Execute success/failure actions and trigger hooks on failure.
  Future<T> foldWithHooks<T>(
    Future<T> Function(S value) onSuccess,
    Future<T> Function(F failure, StackTrace stackTrace) onFailure, {
    String? useCaseName,
    StackTrace? stackTrace,
    Map<String, dynamic> metadata = const {},
    List<String> pathSegments = const [],
  }) async {
    return fold((value) => onSuccess(value), (error) async {
      final st = stackTrace ?? StackTrace.current;
      final artifactId =
          metadata['taskId']?.toString() ??
          'failure_${DateTime.now().millisecondsSinceEpoch}';

      ArtifactPublisher.instance.publishFireAndForget(
        metadata['html'] ?? metadata['data'] ?? error.message,
        id: artifactId,
        contentType: 'text/html; charset=utf-8',
        reason: 'failure',
        source: useCaseName,
        label: error.runtimeType.toString(),
        metadata: metadata,
        stackTrace: st,
        pathSegments: pathSegments,
      );

      return onFailure(error, st);
    });
  }
}
