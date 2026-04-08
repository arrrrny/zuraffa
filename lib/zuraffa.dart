library;

import 'src/core/failure.dart';
import 'src/core/failure_hooks.dart';
import 'src/core/failure_reporter.dart';
import 'src/core/failure_reporter_registry.dart';
import 'src/core/otel_failure_reporter.dart';
import 'src/core/otel_log_exporter.dart';
import 'src/core/retry_policy.dart';

/// Zuraffa
///
/// A comprehensive Clean Architecture framework for Flutter applications
/// with Result-based error handling, dependency injection, and minimal boilerplate.
///
/// ## Overview
///
/// This package provides the building blocks for implementing Clean Architecture
/// in Flutter applications:

///
/// - **StreamUseCase**: Reactive operations that emit multiple values over time
/// - **SyncUseCase**: Synchronous operations that return immediately without async
/// - **BackgroundUseCase**: CPU-intensive operations that run on a separate isolate
/// - **Controller**: Manages UI state and coordinates with UseCases
/// - **Presenter**: Optional orchestration layer for complex business flows
/// - **Result**: Type-safe success/failure handling
/// - **AppFailure**: Sealed failure hierarchy for exhaustive error handling
///
/// ## Quick Start
///
/// ```dart
/// // 1. Create a UseCase
/// class GetUserUseCase extends UseCase<User, String> {
///   final UserRepository _repository;
///   GetUserUseCase(this._repository);
///
///   @override
///   Future<User> execute(String userId, CancelToken? cancelToken) async {
///     return _repository.getUser(userId);
///   }
/// }
///
/// // 2. Use it in a Controller
/// class UserController extends Controller {
///   final GetUserUseCase _getUser;
///
///   UserState _state = const UserState();
///   UserState get state => _state;
///
///   UserController(UserRepository repo) : _getUser = GetUserUseCase(repo);
///
///   Future<void> loadUser(String id) async {
///     _setState(_state.copyWith(isLoading: true));
///     (await _getUser(id)).fold(
///       (user) => _setState(_state.copyWith(user: user, isLoading: false)),
///       (failure) => _setState(_state.copyWith(error: failure, isLoading: false)),
///     );
///   }
///
///   void _setState(UserState newState) {
///     _state = newState;
///     refreshUI();
///   }
/// }
///
/// // 3. Create a View
/// class UserPage extends CleanView {
///   @override
///   State<UserPage> createState() => _UserPageState();
/// }
///
/// class _UserPageState extends CleanViewState<UserPage, UserController> {
///   _UserPageState() : super(UserController(getIt<UserRepository>()));
///
///   @override
///   Widget get view {
///     return Scaffold(
///       key: globalKey,
///       body: ControlledWidgetBuilder<UserController>(
///         builder: (context, controller) {
///           if (controller.state.isLoading) {
///             return const CircularProgressIndicator();
///           }
///           return Text(controller.state.user?.name ?? 'No user');
///         },
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Error Handling
///
/// All operations return `Result<T, AppFailure>` for type-safe error handling:
///
/// ```dart
/// final result = await getUserUseCase('user-123');
///
/// // Pattern matching with fold
/// result.fold(
///   (user) => showUser(user),
///   (failure) => showError(failure),
/// );
///
/// // Or use switch expression
/// switch (failure) {
///   case NotFoundFailure():
///     showNotFound();
///   case NetworkFailure():
///     showOfflineMessage();
///   case UnauthorizedFailure():
///     navigateToLogin();
///   default:
///     showGenericError();
/// }
/// ```

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'src/presentation/controller.dart';

// ============================================================
// Core - Error Handling & Utilities
// ============================================================

/// Re-exported essential packages so users don't need separate dependencies
export 'package:go_router/go_router.dart';
export 'package:get_it/get_it.dart';
export 'package:hive_ce/hive_ce.dart';
export 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Result type for type-safe success/failure handling
export 'src/core/result.dart';

/// Failure types for error classification
export 'src/core/failure.dart';

/// Cancellation token for cooperative cancellation
export 'src/core/cancel_token.dart';

/// Parameter types for UseCases
///
/// Includes:
/// - [NoParams] - For UseCases that don't need parameters
/// - [Params] - Generic map-based parameters
/// - [QueryParams] - For querying a single entity
/// - [ListQueryParams] - For querying lists with filtering, sorting, pagination
/// - [CreateParams] - For creating entities
/// - [UpdateParams] - For updating entities
/// - [DeleteParams] - For deleting entities
/// - [InitializationParams] - For repository/data source initialization
/// - [Settings] - Custom settings
/// - [Credentials] - Authentication credentials
export 'src/core/params/index.dart';

/// Partial type for partial updates
export 'src/core/partial.dart';

/// Loggable mixin for logging capabilities
export 'src/core/loggable.dart';

/// FailureHandler mixin for handling failures
export 'src/core/failure_handler.dart';

/// CachePolicy abstraction for cache expiration strategies
export 'src/core/cache_policy.dart';

/// Concrete cache policy implementations (Daily, AppRestart, TTL)
export 'src/core/cache_policies.dart';

/// Abstract failure reporter contract
export 'src/core/failure_report_queue.dart' show FailureReportQueue;
export 'src/core/failure_report_store.dart' show FailureReportStore;
export 'src/core/failure_reporter.dart';
export 'src/core/failure_reporter_registry.dart' show FailureReporterRegistry;
export 'src/core/otel_failure_reporter.dart' show OtelFailureReporter;
export 'src/core/otel_log_exporter.dart' show OtelLogExporter;
export 'src/core/otel_tracer.dart' show OtelTracer;
export 'package:opentelemetry/api.dart' show Attribute, SpanKind;
export 'src/core/retry_policies.dart'
    show ExponentialBackoffRetryPolicy, FixedIntervalRetryPolicy, NoRetryPolicy;
export 'src/core/retry_policy.dart' show ReportRetryPolicy;

/// Artifact publisher — general-purpose hook system for publishing
/// artifacts (HTML, images, files) for any reason (failure, scan, debug).
export 'src/core/artifact_publisher.dart'
    show ArtifactPublisher, ArtifactHook, ArtifactContext, MinIOArtifactHook;

/// Failure hooks — backward-compatible layer delegating to ArtifactPublisher.
export 'src/core/failure_hooks.dart'
    show
        FailureHook,
        FailureHookManager,
        FailureContext,
        MinIOUploadHook,
        ResultFailureHooks;

/// Lightweight S3-compatible MinIO client with AWS Signature V4.
export 'src/core/minio_client.dart' show MinioClient;

export 'src/core/generation/generation_context.dart';
export 'src/core/context/file_system.dart';
export 'src/core/context/context_store.dart';
export 'src/core/context/progress_reporter.dart';
export 'src/core/ast/ast_helper.dart';
export 'src/core/ast/file_parser.dart';
export 'src/core/ast/ast_modifier.dart';
export 'src/core/ast/node_finder.dart';
export 'src/core/ast/append_executor.dart';
export 'src/core/ast/strategies/append_strategy.dart';
export 'src/core/ast/strategies/method_append_strategy.dart';
export 'src/core/ast/strategies/export_append_strategy.dart';
export 'src/plugins/usecase/usecase_plugin.dart';
export 'src/plugins/repository/repository_plugin.dart';
export 'src/core/builder/code_builder_factory.dart';
export 'src/core/builder/factories/usecase_factory.dart';
export 'src/core/builder/factories/repository_factory.dart';
export 'src/core/builder/factories/vpc_factory.dart';
export 'src/core/builder/factories/route_factory.dart';
export 'src/core/builder/patterns/common_patterns.dart';
export 'src/core/builder/patterns/usecase_patterns.dart';
export 'src/core/builder/patterns/repository_patterns.dart';
export 'src/core/builder/patterns/vpc_patterns.dart';
export 'src/core/builder/shared/spec_library.dart';
export 'src/core/plugin_system/plugin_interface.dart';
export 'src/core/plugin_system/plugin_lifecycle.dart';
export 'src/core/plugin_system/plugin_registry.dart';
export 'src/core/transaction/file_operation.dart';
export 'src/core/transaction/generation_transaction.dart';
export 'src/core/transaction/transaction_result.dart';
export 'src/core/transaction/conflict_detector.dart';

// ============================================================
// Zorphy Integration - Type-safe filtering
// ============================================================

/// Re-export Zorphy's types and extensions for type-safe queries
///
/// This includes:
/// - Filter operators: Eq, And, Or, Not, Gt, Gte, Lt, Lte, Contains, etc.
/// - Field, Filter, Sort types
/// - Iterable extensions for filter() and sort()
export 'package:zorphy_annotation/zorphy_annotation.dart';

// ============================================================
// Domain - Business Logic
// ============================================================

/// UseCase base class for single-shot operations
export 'src/domain/usecase.dart';

/// StreamUseCase for reactive/streaming operations
export 'src/domain/stream_usecase.dart';

/// SyncUseCase for synchronous operations
export 'src/domain/sync_usecase.dart';

/// BackgroundUseCase for isolate-based operations
export 'src/domain/background_usecase.dart';

/// Observer for callback-based stream listening (optional)
export 'src/domain/observer.dart';

// ============================================================
// Presentation - UI Layer
// ============================================================

/// Controller for state management
export 'src/presentation/controller.dart';

/// Presenter for complex orchestration (optional)
export 'src/presentation/presenter.dart';

/// CleanView and CleanViewState base classes
export 'src/presentation/view.dart';

/// ResponsiveViewState for responsive layouts
export 'src/presentation/responsive_view.dart';

/// ControlledWidgetBuilder and variants
export 'src/presentation/controlled_widget.dart';

// ============================================================
// Extensions
// ============================================================

/// Future extensions for Result conversion
export 'src/extensions/future_extensions.dart';

// ============================================================
// Utilities
// ============================================================

/// Test utilities (matchers, observers)
export 'src/utils/test_utils.dart';

// ============================================================
// Framework Configuration
// ============================================================

/// Log levels for Zuraffa framework logging.
enum ZuraffaLogLevel {
  all,
  finest,
  finer,
  fine,
  config,
  info,
  warning,
  severe,
  shout,
  off,
}

/// Application environment types.
enum Environment {
  /// Development environment, usually with detailed logging and debug tools.
  development,

  /// Staging environment, matches production configuration but with test data.
  staging,

  /// Production environment, optimized for performance and security.
  production,
}

/// Global configuration and utilities for Zuraffa.
class Zuraffa {
  Zuraffa._();

  static Environment _environment = Environment.development;
  static bool _isDebugMode = true;

  /// Get the current application environment.
  static Environment get environment => _environment;

  /// Returns true if the application is running in debug mode.
  static bool get isDebugMode => _isDebugMode;

  /// Set the application environment and debug mode.
  ///
  /// typically called at the beginning of `main()`.
  /// If [isDebugMode] is not provided, it defaults to true for development
  /// and false for staging and production.
  /// If [logLevel] is provided, it sets the logging level when [isDebugMode] is true.
  static void setEnvironment(
    Environment env, {
    bool? isDebugMode,
    ZuraffaLogLevel logLevel = ZuraffaLogLevel.all,
  }) {
    _environment = env;
    _isDebugMode = isDebugMode ?? (env == Environment.development);
    if (_isDebugMode || env == Environment.development) {
      enableLogging(level: logLevel);
    } else {
      disableLogging();
    }
    Logger.root.info(
      'Zuraffa environment set to: ${env.name} (isDebugMode: $_isDebugMode, logLevel: ${logLevel.name})',
    );
  }

  static Level toLevel(ZuraffaLogLevel level) {
    switch (level) {
      case ZuraffaLogLevel.all:
        return Level.ALL;
      case ZuraffaLogLevel.finest:
        return Level.FINEST;
      case ZuraffaLogLevel.finer:
        return Level.FINER;
      case ZuraffaLogLevel.fine:
        return Level.FINE;
      case ZuraffaLogLevel.config:
        return Level.CONFIG;
      case ZuraffaLogLevel.info:
        return Level.INFO;
      case ZuraffaLogLevel.warning:
        return Level.WARNING;
      case ZuraffaLogLevel.severe:
        return Level.SEVERE;
      case ZuraffaLogLevel.shout:
        return Level.SHOUT;
      case ZuraffaLogLevel.off:
        return Level.OFF;
    }
  }

  /// Retrieve a [Controller] from the widget tree.
  ///
  /// Use this to access a Controller from widgets that are children
  /// of a [CleanViewState].
  ///
  /// Set [listen] to `false` if you don't need to rebuild when the
  /// Controller changes (e.g., for event handlers).
  ///
  /// ## Example
  /// ```dart
  /// // In a child widget
  /// final controller = Zuraffa.getController<MyController>(context);
  /// controller.doSomething();
  ///
  /// // Without listening (for callbacks)
  /// onPressed: () {
  ///   final controller = Zuraffa.getController<MyController>(
  ///     context,
  ///     listen: false,
  ///   );
  ///   controller.handleButtonPress();
  /// }
  /// ```
  static Con getController<Con extends Controller>(
    BuildContext context, {
    bool listen = true,
  }) {
    return Provider.of<Con>(context, listen: listen);
  }

  /// Enable debug logging for the framework.
  ///
  /// Call this in your `main()` function to see detailed logs from
  /// Controllers, UseCases, and other components.
  ///
  /// ## Example
  /// ```dart
  /// void main() {
  ///   Zuraffa.enableLogging();
  ///   runApp(MyApp());
  /// }
  ///
  /// // With custom log level
  /// void main() {
  ///   Zuraffa.enableLogging(level: ZuraffaLogLevel.warning);
  ///   runApp(MyApp());
  /// }
  /// ```
  static void enableLogging({
    ZuraffaLogLevel level = ZuraffaLogLevel.all,
    void Function(LogRecord record)? onRecord,
  }) {
    Logger.root.level = toLevel(level);
    Logger.root.onRecord.listen(onRecord ?? _defaultLogHandler);
    Logger.root.info('Zuraffa logging enabled');
  }

  /// Disable logging.
  static void disableLogging() {
    Logger.root.level = toLevel(ZuraffaLogLevel.off);
  }

  // ============================================================
  // Failure and Log Reporting
  // ============================================================

  static OtelLogExporter? _otelLogExporter;

  /// Register a failure reporter.
  ///
  /// Failures from all UseCases and FailureHandlers will be
  /// automatically reported to registered reporters.
  ///
  /// ## Example
  /// ```dart
  /// void main() {
  ///   Zuraffa.addFailureReporter(
  ///     OtelFailureReporter(
  ///       collectorEndpoint: Uri.parse('https://otel.example.com/v1/traces'),
  ///       serviceName: 'my_app',
  ///     ),
  ///   );
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> addFailureReporter(
    FailureReporter reporter, {
    ReportRetryPolicy? retryPolicy,
    int? maxQueueSize,
    int? maxBatchSize,
    Duration? flushInterval,
    bool persistFailures = false,
  }) async {
    if (retryPolicy != null ||
        maxQueueSize != null ||
        maxBatchSize != null ||
        flushInterval != null ||
        persistFailures) {
      FailureReporterRegistry.instance.configure(
        retryPolicy: retryPolicy,
        maxQueueSize: maxQueueSize,
        maxBatchSize: maxBatchSize,
        flushInterval: flushInterval,
        persistFailures: persistFailures,
      );
    }
    await FailureReporterRegistry.instance.register(reporter);
  }

  /// Remove a failure reporter by ID.
  static Future<void> removeFailureReporter(String id) async {
    await FailureReporterRegistry.instance.unregister(id);
  }

  /// Convenience: set up OpenTelemetry failure reporting in one call.
  ///
  /// ## Example
  /// ```dart
  /// void main() {
  ///   Zuraffa.enableOtelReporting(
  ///     collectorEndpoint: Uri.parse('https://otel.example.com/v1/traces'),
  ///     serviceName: 'my_app',
  ///     apiKey: 'my_api_key',
  ///   );
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> enableOtelReporting({
    required Uri collectorEndpoint,
    required String serviceName,
    String? apiKey,
    ReportRetryPolicy? retryPolicy,
    int? maxQueueSize,
    Duration? flushInterval,
    bool persistFailures = false,
    bool exportLogs = false,
    ZuraffaLogLevel remoteLogLevel = ZuraffaLogLevel.warning,
  }) async {
    await addFailureReporter(
      OtelFailureReporter(
        collectorEndpoint: collectorEndpoint,
        serviceName: serviceName,
        apiKey: apiKey,
      ),
      retryPolicy: retryPolicy,
      maxQueueSize: maxQueueSize,
      flushInterval: flushInterval,
      persistFailures: persistFailures,
    );

    if (exportLogs) {
      _otelLogExporter?.dispose();
      _otelLogExporter = OtelLogExporter(
        collectorBaseEndpoint: collectorEndpoint,
        serviceName: serviceName,
        apiKey: apiKey,
        remoteLogLevel: remoteLogLevel,
      )..start();
    }
  }

  /// Flush all pending failure reports.
  static Future<void> flushFailureReports() async {
    await FailureReporterRegistry.instance.flush();
  }

  /// Dispose all failure reporters and flush pending reports.
  ///
  /// Call this on app shutdown.
  static Future<void> disposeFailureReporters() async {
    await FailureReporterRegistry.instance.dispose();
    await _otelLogExporter?.dispose();
    _otelLogExporter = null;
  }

  // ============================================================
  // Artifact Publisher
  // ============================================================

  /// Register an artifact hook that reacts to published artifacts.
  ///
  /// Common hooks include [MinIOArtifactHook] for uploading to storage.
  ///
  /// ## Example
  /// ```dart
  /// Zuraffa.registerArtifactHook(MinIOArtifactHook(
  ///   client: MinioClient(
  ///     endpoint: 'http://localhost:9000',
  ///     accessKey: 'minioadmin',
  ///     secretKey: 'minioadmin',
  ///   ),
  ///   bucket: 'artifacts',
  /// ));
  /// ```
  static void registerArtifactHook(ArtifactHook hook) {
    ArtifactPublisher.instance.register(hook);
  }

  /// Unregister an artifact hook by its [id].
  static void unregisterArtifactHook(String id) {
    ArtifactPublisher.instance.unregister(id);
  }

  /// Convenience: set up MinIO artifact storage in one call.
  ///
  /// Registers a [MinIOArtifactHook] that handles all artifact types —
  /// HTML on failure, scanned images, debug snapshots, etc.
  ///
  /// - [endpoint]: MinIO server URL, e.g. `http://localhost:9000`
  /// - [accessKey]: S3 access key (MinIO username)
  /// - [secretKey]: S3 secret key (MinIO password)
  /// - [bucket]: target bucket name (auto-created on first upload)
  /// - [region]: AWS region (default: `us-east-1`)
  /// - [pathPrefix]: optional prefix like `prod/` or `staging/`
  ///
  /// ## Example
  /// ```dart
  /// void main() async {
  ///   Zuraffa.setEnvironment(Environment.production);
  ///   await Zuraffa.enableOtelReporting(
  ///     collectorEndpoint: Uri.parse('https://otel.example.com/v1/traces'),
  ///     serviceName: 'my_app',
  ///   );
  ///   Zuraffa.enableMinIOArtifacts(
  ///     endpoint: 'https://minio.myapp.com',
  ///     accessKey: env.minioAccessKey,
  ///     secretKey: env.minioSecretKey,
  ///     bucket: 'artifacts',
  ///     pathPrefix: 'prod/',
  ///   );
  ///   runApp(MyApp());
  /// }
  /// ```
  static void enableMinIOArtifacts({
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
    registerArtifactHook(
      MinIOArtifactHook.fromParams(
        endpoint: endpoint,
        accessKey: accessKey,
        secretKey: secretKey,
        bucket: bucket,
        region: region,
        ensureBucketExists: ensureBucketExists,
        pathPrefix: pathPrefix,
        includeReasonInKey: includeReasonInKey,
        includeSourceInKey: includeSourceInKey,
        extensionOverrides: extensionOverrides,
      ),
    );
    Logger.root.info(
      'Zuraffa MinIO artifact storage enabled: $endpoint/$bucket',
    );
  }

  /// Publish an artifact to all registered hooks (fire-and-forget).
  ///
  /// Use this anywhere in your app to publish artifacts — HTML from
  /// failed scrapes, scanned product images, debug screenshots, etc.
  ///
  /// - [data]: The artifact payload (`String`, `Uint8List`, etc.)
  /// - [contentType]: MIME type (e.g. `text/html`, `image/jpeg`)
  /// - [reason]: Why this artifact is being published
  /// - [source]: Which component published it (e.g. `'ParsingProvider'`)
  /// - [label]: Human-readable label (e.g. `'NetworkFailure'`, `'barcode_scan'`)
  /// - [metadata]: Additional context (task ID, URL, etc.)
  ///
  /// ## Examples
  /// ```dart
  /// // HTML from a failed operation
  /// Zuraffa.publishArtifact(
  ///   rawHtml,
  ///   id: entityId,
  ///   contentType: 'text/html; charset=utf-8',
  ///   reason: 'failure',
  ///   source: 'NetworkClient',
  ///   label: 'RequestFailed',
  ///   metadata: {'entityId': entity.id, 'url': request.url},
  /// );
  ///
  /// // Scanned product image
  /// Zuraffa.publishArtifact(
  ///   imageBytes,
  ///   id: scanId,
  ///   contentType: 'image/jpeg',
  ///   reason: 'scan',
  ///   source: 'ImageCapture',
  ///   label: 'product_scan',
  ///   metadata: {'barcode': '1234567890'},
  /// );
  ///
  /// // Debug snapshot
  /// Zuraffa.publishArtifact(
  ///   screenshotBytes,
  ///   id: snapshotId,
  ///   contentType: 'image/png',
  ///   reason: 'debug',
  ///   source: 'CheckpointTool',
  ///   label: 'workflow_step_3',
  /// );
  /// ```
  /// - [id]: Business entity ID for later lookup.
  static void publishArtifact(
    dynamic data, {
    required String id,
    required String contentType,
    required String reason,
    String? source,
    String? label,
    Map<String, dynamic> metadata = const {},
    StackTrace? stackTrace,
    List<String> pathSegments = const [],
    String? traceId,
    String? spanId,
  }) {
    ArtifactPublisher.instance.publishFireAndForget(
      data,
      id: id,
      contentType: contentType,
      reason: reason,
      source: source,
      label: label,
      metadata: metadata,
      stackTrace: stackTrace,
      pathSegments: pathSegments,
      traceId: traceId,
      spanId: spanId,
    );
  }

  /// Publish an artifact to all registered hooks (awaited).
  ///
  /// Same as [publishArtifact] but waits for all hooks to complete.
  static Future<void> publishArtifactAwaited(
    dynamic data, {
    required String id,
    required String contentType,
    required String reason,
    String? source,
    String? label,
    Map<String, dynamic> metadata = const {},
    StackTrace? stackTrace,
    List<String> pathSegments = const [],
    String? traceId,
    String? spanId,
  }) async {
    await ArtifactPublisher.instance.publish(
      data,
      id: id,
      contentType: contentType,
      reason: reason,
      source: source,
      label: label,
      metadata: metadata,
      stackTrace: stackTrace,
      pathSegments: pathSegments,
      traceId: traceId,
      spanId: spanId,
    );
  }

  // ============================================================
  // Backward-compatible Failure Hooks
  // ============================================================

  /// Register a failure hook that reacts to errors.
  ///
  /// @deprecated Use [registerArtifactHook] with [ArtifactHook] instead.
  static void registerFailureHook(FailureHook hook) {
    FailureHookManager().register(hook);
  }

  /// Unregister a failure hook by its [id].
  ///
  /// @deprecated Use [unregisterArtifactHook] instead.
  static void unregisterFailureHook(String id) {
    FailureHookManager().unregister(id);
  }

  /// Convenience: set up MinIO artifact uploads for scrape failures.
  ///
  /// @deprecated Use [enableMinIOArtifacts] instead.
  static void enableMinIOFailureArtifacts({
    required String endpoint,
    required String accessKey,
    required String secretKey,
    required String bucket,
    String region = 'us-east-1',
    bool ensureBucketExists = true,
    String? pathPrefix,
    String htmlContentType = 'text/html; charset=utf-8',
  }) {
    enableMinIOArtifacts(
      endpoint: endpoint,
      accessKey: accessKey,
      secretKey: secretKey,
      bucket: bucket,
      region: region,
      ensureBucketExists: ensureBucketExists,
      pathPrefix: pathPrefix,
    );
  }

  /// Dispose all artifact and failure hooks.
  ///
  /// Call this on app shutdown alongside [disposeFailureReporters].
  static void disposeFailureHooks() {
    ArtifactPublisher.instance.dispose();
  }

  static void _defaultLogHandler(LogRecord record) {
    final emoji = _levelEmoji(record.level);
    final message = '$emoji ${record.loggerName}: ${record.message}';

    // ignore: avoid_print
    print(message);

    if (record.error != null) {
      // ignore: avoid_print
      print('  Error: ${record.error}');
    }

    if (record.stackTrace != null) {
      // ignore: avoid_print
      print('  Stack: ${record.stackTrace}');
    }
  }

  static String _levelEmoji(Level level) {
    if (level >= Level.SEVERE) return '🔴';
    if (level >= Level.WARNING) return '🟠';
    if (level >= Level.INFO) return '🔵';
    if (level >= Level.FINE) return '⚪';
    return '⚫';
  }
}
