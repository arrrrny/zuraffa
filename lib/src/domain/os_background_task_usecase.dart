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
/// - **Desktop / Web**: Not supported; calling [register] is a no-op.
///
/// ## CRITICAL: Background Isolate Dispatch
///
/// On Android, workmanager spawns a **fresh isolate** that does NOT share
/// memory with the main isolate. Your app MUST provide its own top-level
/// callback dispatcher that contains a compile-time map of task handlers:
///
/// ```dart
/// @pragma('vm:entry-point')
/// void myAppCallbackDispatcher() {
///   OsBackgroundTask.dispatch({
///     'com.app.sync-data': SyncDataTaskUseCase.callbackHandler,
///     'com.app.cleanup': CleanupTaskUseCase.callbackHandler,
///   });
/// }
///
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await OsBackgroundTask.initialize(
///     callbackDispatcher: myAppCallbackDispatcher,
///   );
///   // Create use case instances for main-isolate use:
///   final syncTask = SyncDataTaskUseCase(dataService);
///   await syncTask.register();
///   runApp(MyApp());
/// }
/// ```
///
/// ## Background Isolate Limitations
///
/// Instance dependencies (services, repositories) from the main isolate are
/// NOT available in the background isolate. Generated `callbackHandler`
/// methods must reconstruct dependencies using isolate-safe mechanisms:
/// 1. Re-initialize GetIt or other DI containers in the background isolate
/// 2. Read data from isolate-safe storage (Hive, SharedPreferences)
/// 3. Use top-level functions that don't rely on instance state
///
/// ## Example
///
/// ```dart
/// class SyncDataTask extends OsBackgroundTaskUseCase<void> {
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
///
///   // Generated static handler (referenced in your app's dispatcher):
///   static Future<void> callbackHandler() async {
///     // Reconstruct dependencies in background isolate:
///     final getIt = GetIt.instance;
///     getIt.registerSingleton(DataService());
///     final service = getIt<DataService>();
///     await service.syncAll();
///   }
/// }
/// ```
abstract class OsBackgroundTaskUseCase<T> with Loggable {
  /// The task descriptor for OS scheduler registration.
  ///
  /// Subclasses must override this to define the task's unique identifier,
  /// name, and scheduling parameters.
  OsBackgroundTaskDescriptor get descriptor;

  /// The business logic to execute when the OS fires this background task.
  ///
  /// This method may run in a **separate isolate** on Android. Keep it
  /// lightweight and isolate-safe.
  ///
  /// workmanager does not pass parameterized data to callbacks; subclasses
  /// should read any required data from isolate-safe storage inside this method.
  Future<T> execute(NoParams params);

  /// Register this task with the OS background scheduler.
  ///
  /// **IMPORTANT**: Before calling this, ensure your app's top-level callback
  /// dispatcher (passed to [OsBackgroundTask.initialize]) includes an entry
  /// for [descriptor.identifier] in its handlers map. See class documentation
  /// for the complete setup pattern.
  ///
  /// Returns `true` if registration succeeded.
  Future<bool> register() async {
    return OsBackgroundTask.register(descriptor);
  }

  /// Cancel this task from the OS scheduler.
  ///
  /// Returns `true` if cancellation succeeded.
  Future<bool> cancel() async {
    return OsBackgroundTask.cancel(descriptor.identifier);
  }
}
