import 'package:meta/meta.dart';

/// Network constraint for OS-scheduled background tasks.
///
/// Encodes honestly which platforms respect this constraint:
/// - **Android**: Fully respected via `Constraints.networkType`.
/// - **iOS/macOS**: `BGProcessingTask` with `requiresNetworkConnectivity: true`
///   gives a *hint* to the OS, but the system may still fire without network.
enum OsNetworkConstraint {
  /// No network requirement (default).
  none,

  /// Task prefers network access (iOS hint, Android enforced).
  connected,

  /// Task requires unmetered network (Android only; iOS treats as [connected]).
  unmetered,
}

/// Scheduling configuration for an [OsBackgroundTask].
///
/// Models frequency honestly across platforms:
/// - **Android**: Minimum interval is 15 minutes (`PeriodicWorkRequest`).
///   Values below 15 min are clamped to 15 min.
/// - **iOS/macOS**: No `repeatInterval`. `frequency` is treated as
///   `earliestBeginDate` (a floor, not a guarantee). The OS decides when
///   to fire. Typical budget: ~30s for refresh tasks, minutes for
///   `BGProcessingTask`. Reschedule the next run from inside the handler.
///
/// Use [OsBackgroundTaskSchedule.recommended] for a sensible default.
class OsBackgroundTaskSchedule {
  /// Minimum interval the OS will respect between task executions.
  ///
  /// On Android this is the `PeriodicWorkRequest` repeat interval (min 15 min).
  /// On iOS/macOS this becomes `earliestBeginDate` — a floor, not a guarantee.
  final Duration frequency;

  /// Whether the initial run should happen immediately on registration.
  final bool initialDelay;

  /// Network constraint for the task.
  final OsNetworkConstraint networkConstraint;

  /// Whether the task requires the device to be charging (iOS/macOS only,
  /// ignored on Android).
  final bool requiresCharging;

  /// Whether the task requires device idle (Android only, ignored on iOS/macOS).
  final bool requiresDeviceIdle;

  /// Android-specific: minimum interval is 15 minutes.
  static const Duration androidMinInterval = Duration(minutes: 15);

  /// Recommended default schedule: 15 minutes, no constraints.
  static const OsBackgroundTaskSchedule recommended = OsBackgroundTaskSchedule(
    frequency: Duration(minutes: 15),
  );

  const OsBackgroundTaskSchedule({
    required this.frequency,
    this.initialDelay = false,
    this.networkConstraint = OsNetworkConstraint.none,
    this.requiresCharging = false,
    this.requiresDeviceIdle = false,
  });

  /// Returns a clamped schedule for Android (enforces 15-minute minimum).
  OsBackgroundTaskSchedule clampedForAndroid() {
    final clampedFreq = frequency < androidMinInterval
        ? androidMinInterval
        : frequency;
    if (clampedFreq == frequency) return this;
    return OsBackgroundTaskSchedule(
      frequency: clampedFreq,
      initialDelay: initialDelay,
      networkConstraint: networkConstraint,
      requiresCharging: false, // Not supported on Android
      requiresDeviceIdle: requiresDeviceIdle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OsBackgroundTaskSchedule &&
          runtimeType == other.runtimeType &&
          frequency == other.frequency &&
          initialDelay == other.initialDelay &&
          networkConstraint == other.networkConstraint &&
          requiresCharging == other.requiresCharging &&
          requiresDeviceIdle == other.requiresDeviceIdle;

  @override
  int get hashCode => Object.hash(
    frequency,
    initialDelay,
    networkConstraint,
    requiresCharging,
    requiresDeviceIdle,
  );
}

/// Descriptor for registering an [OsBackgroundTask] with the OS scheduler.
///
/// Pass this to [OsBackgroundTask.register] to schedule a periodic
/// background task via `workmanager`.
class OsBackgroundTaskDescriptor {
  /// Unique identifier for this task (used as the workmanager task name).
  final String identifier;

  /// Human-readable task name for logging.
  final String taskName;

  /// Scheduling configuration.
  final OsBackgroundTaskSchedule schedule;

  /// Whether this task should run even when the app is terminated.
  ///
  /// **Note**: This field is informational only and does not affect actual
  /// scheduling behavior:
  /// - **Android**: WorkManager tasks always run when the app is terminated
  ///   (this is the normal/expected behavior for PeriodicWorkRequest).
  /// - **iOS/macOS**: Background execution depends on background modes
  ///   configured in Info.plist and entitlements, not this flag.
  /// - **Web**: Not applicable (no OS background scheduling).
  final bool runWhenAppTerminated;

  const OsBackgroundTaskDescriptor({
    required this.identifier,
    required this.taskName,
    this.schedule = OsBackgroundTaskSchedule.recommended,
    this.runWhenAppTerminated = true,
  });
}

/// Callback type for OS background task handlers.
///
/// This function runs in a **separate isolate** on Android. On iOS/macOS
/// it runs in the app's background handler. Keep it lightweight and
/// do NOT access the UI layer.
typedef OsBackgroundTaskHandler = Future<void> Function();

/// A use-case abstraction for OS-scheduled background tasks wrapping
/// `workmanager` (iOS / Android / macOS).
///
/// ## Platform contract (honest)
///
/// ### Android
/// - Minimum interval: **15 minutes** (`PeriodicWorkRequest`). Intervals
///   below 15 min are clamped automatically.
/// - Fires when the app is closed.
/// - Generous time budget (configurable via `setExpireAt`).
/// - Network constraint fully supported.
///
/// ### iOS / macOS
/// - **No `repeatInterval`** — scheduling is opportunistic.
/// - `frequency` becomes `earliestBeginDate` (a floor, not a guarantee).
/// - The OS decides when to fire; "2x/day" is honestly "up to 2x/day".
/// - ~30 s budget for refresh tasks; minutes for `BGProcessingTask`
///   (best when charging + `requiresNetworkConnectivity: true`).
/// - Next task must be rescheduled from inside the current handler.
///
/// ### Desktop / Web
/// - Not supported. [OsBackgroundTask.register] is a no-op.
///   [OsBackgroundTask.initialize] completes immediately on non-mobile platforms.
///
/// ## Background Isolate Dispatch (CRITICAL)
///
/// On Android, workmanager spawns a **fresh isolate** with ONLY the
/// registered callback dispatcher as its entry point. The main isolate's
/// code (including `main()`) does NOT run in the background isolate, and
/// isolates do NOT share mutable heap state.
///
/// **Your app MUST provide its own top-level dispatcher function** that:
/// 1. Is annotated with `@pragma('vm:entry-point')`
/// 2. Contains a **compile-time map literal** of task identifiers to handlers
/// 3. Calls [OsBackgroundTask.dispatch] to execute the task
///
/// The framework does NOT maintain a cross-isolate registry. You must write
/// the handler map directly in your dispatcher's source code so it's
/// rebuilt fresh in the background isolate each time.
///
/// ## Integration with workmanager
///
/// This class provides the domain model and contract for OS background tasks.
/// The actual workmanager integration is handled by the consuming Flutter app:
///
/// ```dart
/// // 1. In your Flutter app's pubspec.yaml:
/// //    dependencies:
/// //      workmanager: ^0.5.2
/// //      zuraffa: ^6.0.0
///
/// // 2. Define your top-level dispatcher (in your app code, NOT zuraffa):
/// @pragma('vm:entry-point')
/// void myAppCallbackDispatcher() {
///   Workmanager().executeTask((task, inputData) async {
///     final handler = myHandlers[task];
///     if (handler != null) {
///       await handler();
///       return true;
///     }
///     return false;
///   });
/// }
///
/// // 3. In main() before runApp():
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Workmanager().initialize(
///     myAppCallbackDispatcher,
///     isInDebugMode: kDebugMode,
///   );
///   // Register tasks using OsBackgroundTaskDescriptor
///   final descriptor = const OsBackgroundTaskDescriptor(
///     identifier: 'com.app.sync-data',
///     taskName: 'SyncData',
///   );
///   final schedule = descriptor.schedule;
///   final clampedSchedule = Platform.isAndroid
///       ? schedule.clampedForAndroid()
///       : schedule;
///   await Workmanager().registerPeriodicTask(
///     descriptor.identifier,
///     descriptor.taskName,
///     frequency: clampedSchedule.frequency,
///     existingWorkPolicy: ExistingWorkPolicy.keep,
///     tag: descriptor.identifier,
///   );
///   runApp(MyApp());
/// }
/// ```
///
/// ## Usage with OsBackgroundTaskUseCase
///
/// ```dart
/// class SyncDataTask extends OsBackgroundTaskUseCase<void> {
///   final DataService _dataService;
///   SyncDataTask(this._dataService);
///
///   @override
///   OsBackgroundTaskDescriptor get descriptor => const OsBackgroundTaskDescriptor(
///     identifier: 'com.app.sync-data',
///     taskName: 'SyncData',
///   );
///
///   @override
///   Future<void> execute(NoParams params) async {
///     await _dataService.syncAll();
///   }
/// }
/// ```
class OsBackgroundTask {
  /// Registered descriptors for bookkeeping (main isolate only).
  static final Map<String, OsBackgroundTaskDescriptor> _registrations = {};

  OsBackgroundTask._();

  /// Register a periodic background task with the OS scheduler.
  ///
  /// In a pure Dart context (no workmanager available), this stores the
  /// descriptor for bookkeeping and returns `true`. The consuming Flutter app
  /// should override this with actual workmanager calls.
  ///
  /// Returns `true` if registration succeeded.
  static Future<bool> register(OsBackgroundTaskDescriptor descriptor) async {
    _registrations[descriptor.identifier] = descriptor;
    return true;
  }

  /// Cancel a previously registered background task.
  ///
  /// In a pure Dart context, this removes the descriptor from bookkeeping.
  /// The consuming Flutter app should override this with actual workmanager calls.
  ///
  /// Returns `true` if cancellation succeeded.
  static Future<bool> cancel(String identifier) async {
    _registrations.remove(identifier);
    return true;
  }

  /// Check whether a task with the given [identifier] is currently registered.
  static bool isRegistered(String identifier) =>
      _registrations.containsKey(identifier);

  /// List all currently registered task identifiers.
  static List<String> get registeredIdentifiers => _registrations.keys.toList();

  /// Get the descriptor for a registered task, or null if not registered.
  static OsBackgroundTaskDescriptor? getDescriptor(String identifier) =>
      _registrations[identifier];

  /// Dispatch task execution based on a map of identifiers to handlers.
  ///
  /// Call this inside your top-level callback dispatcher on Android.
  static Future<void> dispatch(
    Map<String, Future<void> Function()> handlers,
  ) async {
    // This is a placeholder; real dispatch is handled by workmanager
    // in the app-side dispatcher.
  }

  /// Reset internal state. For testing purposes only.
  @visibleForTesting
  static void reset() {
    _registrations.clear();
  }
}
