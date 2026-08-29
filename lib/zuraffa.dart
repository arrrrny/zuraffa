library;

import 'src/core/failure_hooks.dart';
import 'src/core/failure_reporter.dart';
import 'src/core/failure_reporter_registry.dart';
import 'src/core/hook.dart';
import 'src/core/hook_registry.dart';
import 'src/core/otel_failure_reporter.dart';
import 'src/core/otel_log_exporter.dart';
import 'src/core/retry_policy.dart';
import 'src/core/zuraffa_bridge_facade.dart';
import 'src/core/module/contracts.dart';

/// Zuraffa
///
/// A comprehensive Clean Architecture framework for Dart and Flutter applications
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
/// - **OsBackgroundTask**: OS-scheduled periodic background tasks via workmanager
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
/// class _UserPageState extends CleanViewState<UserPage, UserController, void> {
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

import 'package:logging/logging.dart';

// ============================================================
// Core - Error Handling & Utilities
// ============================================================

/// Re-exported essential packages so users don't need separate dependencies
export 'package:get_it/get_it.dart';
export 'package:hive_ce/hive_ce.dart';

/// Result type for type-safe success/failure handling
export 'src/core/result.dart';

/// Failure types for error classification
export 'src/core/failure.dart';

/// VM Service extension bridge — exposes UseCases as dart:developer extensions
export 'src/core/api_bridge.dart';

/// Endpoint metadata model for the API bridge
export 'src/core/api_endpoint.dart';

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

/// FetchStrategy abstraction for pluggable data-fetching pipelines
export 'src/core/fetch_strategy.dart';

/// StrategyPlugin — generates FetchStrategy skeletons for a domain
export 'src/plugins/strategy/strategy_plugin.dart';

/// SyncStrategy abstraction for offline-first synchronization
export 'src/core/sync_strategy.dart';
export 'src/core/sync_status.dart';
export 'src/core/sync_operation.dart';
export 'src/core/sync_metadata.dart';
export 'src/core/sync_direction.dart';
export 'src/core/sync_config.dart';

/// Sync runtime infrastructure (used by generated sync code)
export 'src/plugins/sync/builders/sync_metadata_store.dart';
export 'src/plugins/sync/builders/push_only_sync_strategy.dart';
export 'src/plugins/sync/builders/bidirectional_sync_strategy.dart';

/// Abstract failure reporter contract
export 'src/core/failure_report_queue.dart' show FailureReportQueue;
export 'src/core/failure_report_store.dart' show FailureReportStore;
export 'src/core/failure_reporter.dart';
export 'src/core/failure_reporter_registry.dart' show FailureReporterRegistry;
export 'src/core/otel_failure_reporter.dart' show OtelFailureReporter;
export 'src/core/otel_log_exporter.dart' show OtelLogExporter;
export 'src/core/otel_tracer.dart' show OtelTracer;
export 'package:opentelemetry/api.dart' hide SpanStatus;
export 'src/core/retry_policies.dart'
    show ExponentialBackoffRetryPolicy, FixedIntervalRetryPolicy, NoRetryPolicy;
export 'src/core/retry_policy.dart' show ReportRetryPolicy;

/// Artifact publisher — general-purpose hook system for publishing
/// artifacts (HTML, images, files) for any reason (failure, scan, debug).
export 'src/core/artifact_publisher.dart'
    show ArtifactPublisher, ArtifactHook, ArtifactContext, MinIOArtifactHook;

/// UseCase Hook system — intercept any UseCase at pre/success/failure phases
export 'src/core/hook.dart' show Hook, HookPhase, HookContext;
export 'src/core/hook_registry.dart' show HookRegistry;
export 'src/core/telemetry_hook.dart' show TelemetryHook;

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
// Hide the code-generation plugin interface to avoid naming collision with
// the micro-frontend runtime contract (src/core/module/zuraffa_plugin.dart).
// CLI commands and internal code can still import plugin_interface.dart directly.
export 'src/core/plugin_system/plugin_interface.dart' hide ZuraffaPlugin;
export 'src/core/plugin_system/plugin_lifecycle.dart';
export 'src/core/plugin_system/plugin_registry.dart';

// ============================================================
// Benchmark Contract Library (feature 015-benchmark-plugin)
// ============================================================

/// The benchmark contract surface every Zuraffa app/plugin can implement —
/// interface-only, decoupled from the benchmark plugin implementation
/// (FR-015): scenarios depend only on these types, never on the runner or
/// the plugin wiring. Pure-Dart (no Flutter dependency).
export 'src/core/benchmark/benchmark_contract.dart';
export 'src/core/benchmark/benchmark_result.dart';
export 'src/core/benchmark/benchmark_registry.dart';
export 'src/core/benchmark/benchmark_runner.dart';
export 'src/core/benchmark/metric_collector.dart';
export 'src/core/benchmark/baseline_store.dart';
export 'src/core/benchmark/standard_metrics.dart';
export 'src/core/benchmark/isolate_benchmark_runner.dart';

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

/// OsBackgroundTask for OS-scheduled background tasks wrapping workmanager
export 'src/domain/os_background_task.dart';

/// OsBackgroundTaskUseCase abstract base for OS background task use cases
export 'src/domain/os_background_task_usecase.dart';

/// Observer for callback-based stream listening (optional)
export 'src/domain/observer.dart';

// ============================================================
// Presentation - UI Layer
// ============================================================

/// Controller for state management

/// Presenter for complex orchestration (optional)

/// CleanView and CleanViewState base classes

/// ResponsiveViewState for responsive layouts

/// AdaptiveViewState for platform/device-aware layouts

/// ControlledWidgetBuilder and variants

// ============================================================
// Platform-Aware Presentation
// ============================================================

/// Device and platform classification for adaptive layouts

/// Adaptive application shells

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
// V6 Reactive Signals
// ============================================================

/// Signal — zero-cost reactive primitive.
export 'src/core/signals/signal.dart';

/// SignalResult — reactive Result wrapper backed by Signal.
export 'src/core/signals/signal_result.dart';

/// ZuraffaUseCase — v6 UseCase contract with SignalResult return type.
export 'src/core/usecase/zuraffa_usecase.dart';

/// ZuraffaContext — lightweight correlation context carrier.
export 'src/core/context/zuraffa_context.dart';

/// TelemetryMesh — global trace/span coordinator and auto-instrumentation.
export 'src/core/telemetry/telemetry_mesh.dart';

// ============================================================
// V6 DDA (Decorator-Driven Architecture) — Compiler Pipeline
// ============================================================

/// DecoratorAST — parsed decorator annotation model.
export 'src/dda/models/decorator_ast.dart';

/// ZorphyContext — code_builder-based injection context.
export 'src/dda/models/zorphy_context.dart';

/// ZorphyDecoratorPlugin — abstract plugin contract.
export 'src/dda/compiler/zorphy_decorator_plugin.dart';

/// ASTScanner — finds @DecoratorName() across the project.
export 'src/dda/compiler/ast_scanner.dart';

/// PluginDiscovery — loads plugins from pubspec.yaml.
export 'src/dda/compiler/plugin_discovery.dart';

/// DecoratorDispatcher — routes annotations to handlers.
export 'src/dda/compiler/decorator_dispatcher.dart';

/// BuildPipeline — 6-stage build orchestrator.
export 'src/dda/compiler/build_pipeline.dart';

// ============================================================
// V6 DI — Auto-Dependency Injection
// ============================================================

/// DependencyScope — lifecycle scopes for DI.
export 'src/core/di/dependency_scope.dart';

/// @Datasource annotation.
export 'src/core/di/datasource.dart';

/// @Repository annotation.
export 'src/core/di/repository.dart';

/// ZuraffaContainer — lightweight DI container.
export 'src/core/di/zuraffa_container.dart';

/// DIPlugin — DDA plugin for @Datasource/@Repository processing.
export 'src/dda/plugins/di/di_plugin.dart';

/// Route annotation — @ZfaRoute, ZuraffaRouteGuard, RouteParams base classes.
export 'src/dda/plugins/route/route_annotation.dart';

/// RouteDDAPlugin — DDA plugin for @Route annotation processing.
export 'src/dda/plugins/route/route_plugin.dart';

/// RouteGenerator — GoRouter configuration generation from @Route metadata.
export 'src/dda/plugins/route/route_generator.dart';

/// CacheStrategy enum, @Cacheable and @CacheInvalidate annotations.
export 'src/dda/plugins/cache/cache_annotation.dart';

/// CacheDDAPlugin — DDA plugin for @Cacheable/@CacheInvalidate processing.
export 'src/dda/plugins/cache/cache_plugin.dart';

/// CacheGenerator — generates zfa_cache.g.dart from @Cacheable metadata.
export 'src/dda/plugins/cache/cache_generator.dart';
export 'src/dda/plugins/middleware/middleware_annotation.dart';
export 'src/dda/plugins/middleware/auth_plugin.dart';
export 'src/dda/plugins/middleware/auth_generator.dart';
export 'src/dda/plugins/middleware/retry_plugin.dart';
export 'src/dda/plugins/middleware/retry_generator.dart';
export 'src/dda/plugins/middleware/track_event_plugin.dart';
export 'src/dda/plugins/middleware/track_event_generator.dart';

/// DIGenerator — code_builder-based DI registration generation.
export 'src/dda/plugins/di/di_generator.dart';

// ============================================================
// V6 State — Fragmented Signal Slices
// ============================================================

// SignalSlice — fine-grained reactive slice wrapping SignalResult.
export 'src/state/slices/signal_slice.dart';

// SlicePresenter — manages multiple slices with backward-compatible state.
export 'src/state/presenter/slice_presenter.dart';

// FragmentBuilder — widget subscribing to a single slice.

// StateMigrator — converts v5 .state.dart to v6 slice pattern.
// The StateMigrator class is hidden from public API but remains accessible
// to migration and doctor commands via direct import.
export 'src/state/migration/state_migrator.dart' hide StateMigrator;

// v5 -> v6 migration tooling
export 'src/migration/migration.dart';

// DomainState — auto-generated read-only slice container.
export 'src/state/domain_state.dart';

// ViewState — developer-editable transient UI state.
export 'src/state/view_state.dart';

// DualLayerPresenter — strict domain/view state separation.
export 'src/state/presenter/dual_layer_presenter.dart';

// StateGenerator — code_builder-based generation with preservation.
export 'src/state/generator/state_generator.dart';

// CacheObserver — observable cache for cross-view state sync.
export 'src/state/cache/cache_observer.dart';

// CacheBinding — binds SignalSlice to cache updates.
export 'src/state/cache/cache_binding.dart';

// CacheBindingPlugin — DDA plugin for @Cacheable processing.
export 'src/state/generator/cache_binding_generator.dart';

// ControlledWidget — base widget with typed controller and lifecycle hooks.

// SignalBuilder — rebuilds on pure UI Signal changes.

// ViewTemplateGenerator — generates ControlledWidget-based views.
export 'src/state/generator/view_template_generator.dart';

// ============================================================
// V6 GraphQL Core
// ============================================================

// GraphQLType — polymorphic GraphQL type hierarchy.
export 'src/graphql/types/graphql_type.dart';

// SchemaParser — two-pass introspection JSON parser.
export 'src/graphql/schema/schema_parser.dart';

// SchemaCache — load/save schema.json with HTTP fetch stub.
export 'src/graphql/cache/schema_cache.dart';

// TypeMapper — GraphQL type to Dart type mapping.
export 'src/graphql/mapping/type_mapper.dart';

// DocumentBuilder — query/mutation/subscription document generation.
export 'src/graphql/document/document_builder.dart';

// GraphQLDocumentBuilder — AST-based .graphql file generation via package:gql.
export 'src/graphql/gql/graphql_document_builder.dart';

// DocumentsDartGenerator — documents.dart with DocumentNode constants.
export 'src/graphql/gql/documents_dart_generator.dart';

// NamingUtils — shared naming utilities for consistent variable naming.
export 'src/graphql/gql/naming_utils.dart';

// GraphQLValidator — validates documents against the cached schema.
export 'src/graphql/validators/graphql_validator.dart';

// GqlFilePreserver — preserves valid user-edited .graphql files.
export 'src/graphql/preservers/gql_file_preserver.dart';

// ============================================================
// V6 GraphQL Client Runtime & Subscriptions
// ============================================================

// GraphQLClientFactory — assembles GraphQLClient from .zfa.json config.
export 'src/graphql/client/graphql_client_factory.dart';

// GraphQLClientProvider — singleton lazily-built client provider.
export 'src/graphql/client/graphql_client_provider.dart';

// SubscriptionStream — GraphQL subscription -> SignalResult streams.
export 'src/graphql/client/subscription_stream.dart';

// ============================================================
// V6 GraphQL Codegen — Schema-to-Full-Stack Generation
// ============================================================

// EntityGenerator — GraphQL OBJECT types -> zorphy $Entity classes.
export 'src/graphql/codegen/entity_generator.dart';

// DtoGenerator — GraphQL INPUT types -> DTO classes.
export 'src/graphql/codegen/dto_generator.dart';

// UnionGenerator — GraphQL UNION types -> sealed class hierarchies.
export 'src/graphql/codegen/union_generator.dart';

// DatasourceGenerator — package:graphql remote datasource.
export 'src/graphql/codegen/datasource_generator.dart';

// RepositoryGenerator — interface + impl delegating to datasource.
export 'src/graphql/codegen/repository_generator.dart';

// DiGenerator — ZuraffaContainer registrations.
export 'src/graphql/codegen/di_generator.dart';

// SliceOrchestrator — orchestrates all generators for a schema slice.
export 'src/graphql/codegen/slice_orchestrator.dart';

// ErrorMappingConfig — .zfa.json graphql.errorMapping -> AppFailure mapping.
export 'src/graphql/codegen/error_mapping_config.dart';

// UnionResultHandler — union result -> AppFailure/SignalResult codegen.
export 'src/graphql/codegen/union_result_handler.dart';

// GraphqlGenerateCommand — `zfa graphql generate` command class.
export 'src/graphql/codegen/graphql_generate_command.dart';

// GraphQL introspection — fetch and parse remote schemas.
export 'src/graphql/graphql_introspection_service.dart';
export 'src/graphql/graphql_schema.dart';
export 'src/graphql/graphql_schema_translator.dart';
export 'src/graphql/graphql_entity_emitter.dart';

// ============================================================
// Micro-Frontend Module System (v6)
// ============================================================

/// Runtime contracts for the micro-frontend plugin architecture (Dart-only parts).
/// [ZuraffaPlugin], [ZuraffaEngine], [ZuraffaDIContainer], and
/// [ZuraffaRouteHandler] ship here.
/// [ZuraffaRouteBuilder] (Widget-returning) and [ZuraffaAppRunner] are in zuraffa_flutter.
export 'src/core/module/route_builder.dart';
export 'src/core/module/di_container.dart';
export 'src/core/module/engine.dart';
export 'src/core/module/zuraffa_plugin.dart';

// ============================================================
// MCP Plugin (issue #369) — runtime tool exposure
// ============================================================

/// Runtime MCP tool contracts: [McpTool], [McpToolResult],
/// [McpToolRegistry], [McpServerPlugin], [McpStdioServer], and
/// [McpSseServer].
/// Together they let a Zuraffa app expose its features as
/// Model Context Protocol tools callable by AI agents.
export 'src/core/module/mcp_tool.dart';
export 'src/core/module/mcp_tool_registry.dart';
export 'src/core/module/mcp_server_plugin.dart';
export 'src/core/module/mcp_stdio_server.dart';
export 'src/mcp/sse_server.dart' show McpSseServer;

// ── Generic session plugin (spec #015) ────────────────────────────────
// Pure-Dart session foundation shared by zuraffa and zuraffa_flutter:
// presets, scoped container, portable serialization, pluggable
// persistence. No Flutter/UI dependencies (SC-004).
export 'src/session/session.dart';
export 'src/session/session_preset.dart';
export 'src/session/session_container.dart';
export 'src/session/session_persistence.dart';
export 'src/session/session_exception.dart';

// ── Secure storage (ecosystem gap #1) ─────────────────────────────────
// Typed at-rest key/value seam for tokens, receipts, and secrets: port +
// in-memory default + codec + SecretStore convenience. No platform
// dependencies — Keychain/Keystore adapters implement SecureStoragePort.
export 'src/secure_storage/secure_storage.dart';
export 'src/secure_storage/secure_storage_codec.dart';
export 'src/secure_storage/secret_store.dart';

// ── Built-in capability plugins (analysis §4) ─────────────────────────
// Everyday device primitives the codegen plugins can assume: biometrics
// (auth enabler), share/clipboard, and app update. Pure-Dart ports +
// in-memory defaults; platform adapters implement them in apps.
export 'src/biometrics/biometrics.dart';
export 'src/biometrics/biometrics_service.dart';
export 'src/share/share.dart';
export 'src/share/share_service.dart';
export 'src/clipboard/clipboard.dart';
export 'src/clipboard/clipboard_service.dart';
export 'src/app_update/app_update.dart';
export 'src/app_update/app_update_service.dart';

// ── Device + logging built-ins (analysis §4, completing the set) ──────
export 'src/device/device.dart';
export 'src/device/device_service.dart';
export 'src/logging/structured_logging.dart';

// ── i18n built-in (the final §4 recommendation) ──────────────────────
// Locale negotiation, typed translation lookup with parameters and
// CLDR pluralization, and live locale switching — pure Dart.
export 'src/i18n/i18n.dart';
export 'src/i18n/i18n_service.dart';

// ── 018-cli-plugin — native, built-in, pure-Dart CLI plugin ───────────
// Standardizes the CLI surface across all Zuraffa apps and lets apps
// cross-reference, interact, and share commands via a shared registry.
// Pure-Dart (FR-012): no package:flutter import anywhere in this subtree.
export 'src/cli/standard/standard.dart';

// ── 023-agent-plugin-ui-render — agent-authored live, interactive UI ──
// `ui.render` tool + streaming UI event channel + action-loop closure.
// Agents author a component tree validated against the UI Vocabulary Schema;
// user interactions route back as semantic actions. confirm-tier actions are
// gated by a policy shell. Per-mission-type vocabulary narrowing restricts
// the agent's allowed components. Pure-Dart (no package:flutter import
// anywhere in this subtree).
//
// `ValidationResult` is hidden here to avoid an ambiguous-export conflict with
// `package:zuraffa/src/core/plugin_system/plugin_lifecycle.dart`, which already
// exports a same-named type from the plugin-lifecycle subsystem. Consumers
// that need the ui_render ValidationResult should import
// `package:zuraffa/src/agent/ui_render/ui_vocabulary_schema.dart` directly.
// NOTE: `MissionTraceRecorder` is defined by BOTH the ui_render plugin
// (#023) and the policy shell (#027, this PR). They are unrelated features
// (render-tree trace vs tool-call trace) that coincidentally share the name.
// The policy shell's `MissionTraceRecorder` is kept in the public barrel;
// ui_render's remains available via its own relative import and is hidden here
// to avoid an ambiguous-export error. See zuraffa.dart policy-shell export.
export 'src/agent/ui_render/ui_render.dart'
    hide ValidationResult, ValidationError, MissionTraceRecorder;

// ── 026-agent-kernel-mission — mission coalescing, cancellation, partial-salvage ──
// The agent kernel's efficiency + safety core. Identical missions coalesce
// into one execution via a composite key (spark type + normalized value +
// country + strategy variant); mid-execution cancellation triggers a grace
// period that disposes resources and salvages partials as `cancelled_partial`;
// an idempotency cache serves repeated submissions within TTL. Single-isolate
// assumption documented; MissionExecutor is the multi-isolate extension point.
// Pure-Dart (no package:flutter import anywhere in this subtree).
export 'src/agent/kernel/agent_kernel.dart'
    hide
        CancelToken,
        Mission,
        MissionEvent,
        MissionEventCompleted,
        MissionEventFailed;

// ── 027-agent-policy-shell — ToolGatingHook, MissionBudgetHook, MissionTraceRecorder ──
// Framework-default safety/governance layer. Tool permission registry
// (safe/confirm/admin) evaluated before every tool call; four-dimension
// mission budgets (calls, wall-clock, tokens, per-tool-class seconds) with
// typed budget-exceeded events and cancellation; hashed-argument Mission
// Trace JSON with concurrent-streaming integrity and an oversized-result
// guard. All hooks composable and individually disableable. Pure-Dart.
export 'src/agent/policy/policy_shell.dart' hide ToolCallContext;

// ── 028-agent-runtime-plugin — AgentRuntimePlugin + McpToolProvider SPI ──
// In-proc kernel host over dart_agent_core. McpToolProvider SPI for device
// packages to self-describe; McpToolRegistry assembles a flat, collision-safe
// tool registry from SPI providers + generated usecase tools + remote MCP
// servers. AgentKernel delegates the agent loop entirely to
// StatefulAgent.runStream (no loop duplication — FR-013). Composes system
// prompt from playbook + tool manifests; wires FallbackLLMClient as default;
// persists per-mission session state via FileStateStorage; supports ordered
// AgentHook registration for policy concerns; exposes kernel.status().
// Pure-Dart (no package:flutter import anywhere in this subtree).
export 'src/agent/runtime/agent_runtime_plugin.dart'
    hide McpTool, AgentHook, McpToolRegistry, AgentKernel;

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

  static bool _disableCache = false;

  /// Whether the API bridge is active in profile mode.
  ///
  /// Defaults to false — profile mode is opt-in.
  /// Set this to `true` before calling `ZuraffaApiBridge.init()` to enable
  /// the bridge in profile builds. Has no effect in release or debug mode.
  ///
  /// Writing to this field also updates [ZuraffaBridgeFacade.enableApiInProfile]
  /// so that ZuraffaApiBridge can read it without importing zuraffa.dart.
  static bool get enableApiInProfile => ZuraffaBridgeFacade.enableApiInProfile;

  static set enableApiInProfile(bool value) {
    ZuraffaBridgeFacade.enableApiInProfile = value;
  }

  /// Get the current application environment.
  static Environment get environment => _environment;

  /// Returns true if the application is running in debug mode.
  static bool get isDebugMode => _isDebugMode;

  /// Returns true if caching is globally disabled.
  ///
  /// When true, all [CachePolicy.isValid] calls should return false,
  /// forcing fresh data to be fetched from remote sources.
  static bool get disableCache => _disableCache;

  /// Globally disable or enable caching.
  ///
  /// Set this to `true` to bypass all caches (e.g., in debug mode
  /// or when a remote config flag requests it).
  static set disableCache(bool value) {
    _disableCache = value;
    Logger.root.info('Zuraffa cache disabled: $value');
  }

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
    bool ensureBucketExists = false,
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
  // Hooks (generic)
  // ============================================================

  /// Register a generic hook.
  ///
  /// Hooks intercept UseCase execution at pre/success/failure phases.
  /// Multiple hooks can be registered simultaneously and all will fire.
  ///
  /// ## Example
  /// ```dart
  /// Zuraffa.registerHook(TelemetryHook());
  /// Zuraffa.registerHook(EngagementHook(repository));
  /// ```
  static void registerHook(Hook hook) {
    HookRegistry.instance.register(hook);
  }

  /// Unregister a hook by ID.
  static void unregisterHook(String id) {
    HookRegistry.instance.unregister(id);
  }

  /// Enable/disable all hooks globally.
  ///
  /// Set to `false` to instantly disable all hooks (GDPR compliance,
  /// debug mode, performance profiling).
  static set hooksEnabled(bool value) {
    HookRegistry.instance.isEnabled = value;
  }

  // ============================================================
  // Interceptors (UseCase pipeline)
  // ============================================================

  /// Global interceptor registry for UseCase pipelines.
  ///
  /// Use [registerInterceptor] to add interceptors. The registry
  /// is keyed by UseCase input type.
  static final interceptorRegistry = InterceptorRegistry();

  /// Register a UseCase interceptor for input type [In] and output
  /// type [Out].
  ///
  /// Interceptors run in registration order. Each receives the
  /// original request and a `next` function to continue the chain.
  ///
  /// ## Example
  /// ```dart
  /// Zuraffa.registerInterceptor<String, User>(
  ///   InterceptorEntry(
  ///     name: 'cache',
  ///     handler: (request, next) {
  ///       final cached = cache.get(request);
  ///       if (cached != null) return SignalResult.success(cached);
  ///       return next(request);
  ///     },
  ///   ),
  /// );
  /// ```
  static void registerInterceptor<In, Out>(InterceptorEntry<In, Out> entry) {
    interceptorRegistry.register<In, Out>(entry);
  }

  /// Clear all registered interceptors.
  static void clearInterceptors() {
    interceptorRegistry.clear();
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
    bool ensureBucketExists = false,
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
