import 'dart:async';

import '../core/loggable.dart';
import '../core/params/no_params.dart';
import 'os_background_task.dart';

/// Abstract base class for OS-scheduled background task use cases.
///
/// Subclasses define:
/// - [descriptor]: The task registration configuration.
/// - [execute]: The business logic to run when the task fires.
///
/// ## Platform notes
///
/// - **Android**: The [execute] method runs in a **separate isolate**.
///   Do NOT access the UI layer, SharedPreferences (unless via isolate-safe
///   APIs), or any main-isolate-only resources.
/// - **iOS/macOS**: Runs in the app's background handler with a limited
///   time budget (~30 s for refresh, minutes for BGProcessingTask).
/// - **Web**: Not supported; calling [register] is a no-op.
///
/// ## Example
///
/// ```dart
/// class SyncDataTask extends OsBackgroundTaskUseCase<void, NoParams> {
///   final DataService _dataService;
///   SyncDataTask(this._dataService);
///
///   @override
///   OsBackgroundTaskDescriptor get descriptor =>
///       const OsBackgroundTaskDescriptor(
///         identifier: 'com.app.sync-data',
///         taskName: 'SyncData',
///         schedule: OsBackgroundTaskSchedule(
///           frequency: Duration(minutes: 30),
///           networkConstraint: OsNetworkConstraint.connected,
///         ),
///       );
///
///   @override
///   Future<void> execute(NoParams params) async {
///     await _dataService.syncAll();
///   }
/// }
/// ```
abstract class OsBackgroundTaskUseCase<T, Params> with Loggable {
  /// The task descriptor for OS scheduler registration.
  ///
  /// Subclasses must override this to define the task's unique identifier,
  /// name, and scheduling parameters.
  OsBackgroundTaskDescriptor get descriptor;

  /// The business logic to execute when the OS fires this background task.
  ///
  /// This method may run in a **separate isolate** on Android. Keep it
  /// lightweight and isolate-safe.
  Future<T> execute(Params params);

  /// Register this task with the OS background scheduler.
  ///
  /// Calls [OsBackgroundTask.register] with this use case's [descriptor]
  /// and a handler that invokes [execute].
  ///
  /// Returns `true` if registration succeeded.
  Future<bool> register() async {
    return OsBackgroundTask.register(
      descriptor,
      _handler,
    );
  }

  /// Cancel this task from the OS scheduler.
  ///
  /// Returns `true` if cancellation succeeded.
  Future<bool> cancel() async {
    return OsBackgroundTask.cancel(descriptor.identifier);
  }

  /// Internal handler bridging the workmanager callback to [execute].
  ///
  /// Uses a default `NoParams` instance since workmanager callbacks
  /// do not pass parameterized data directly. Subclasses that need
  /// data should read it from local storage or a shared preference
  /// inside their [execute] override.
  Future<void> _handler() async {
    // workmanager does not pass typed params to callbacks;
    // subclasses read their data from local storage inside execute().
    try {
      await execute(NoParams() as Params);
    } catch (e, stackTrace) {
      logger.severe(
        '$runtimeType background task failed',
        e,
        stackTrace,
      );
    }
  }
}


