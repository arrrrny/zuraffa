library;

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

/// Result type for type-safe success/failure handling
export 'src/core/result.dart';

/// Failure types for error classification
export 'src/core/failure.dart';

/// Cancellation token for cooperative cancellation
export 'src/core/cancel_token.dart';

/// NoParams sentinel for parameterless UseCases
export 'src/core/no_params.dart';

/// Params class for map-based parameters
export 'src/core/params.dart';

/// InitializationParams for repository and data source initialization
export 'src/core/initialization_params.dart';

/// QueryParams for querying a single entity
export 'src/core/query_params.dart';

/// ListQueryParams for querying a list of entities
export 'src/core/list_query_params.dart';

/// CreateParams for creating an entity
export 'src/core/create_params.dart';

/// UpdateParams for updating an entity
export 'src/core/update_params.dart';

/// DeleteParams for deleting an entity
export 'src/core/delete_params.dart';

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

export 'src/core/generation/generation_context.dart';
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

/// Global configuration and utilities for Zuraffa.
class Zuraffa {
  Zuraffa._();

  static Level _toLevel(ZuraffaLogLevel level) {
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
    Logger.root.level = _toLevel(level);
    Logger.root.onRecord.listen(onRecord ?? _defaultLogHandler);
    Logger.root.info('Zuraffa logging enabled');
  }

  /// Disable logging.
  static void disableLogging() {
    Logger.root.level = _toLevel(ZuraffaLogLevel.off);
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
