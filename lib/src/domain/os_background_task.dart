import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

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
  static const OsBackgroundTaskSchedule recommended =
      OsBackgroundTaskSchedule(frequency: Duration(minutes: 15));

  const OsBackgroundTaskSchedule({
    required this.frequency,
    this.initialDelay = false,
    this.networkConstraint = OsNetworkConstraint.none,
    this.requiresCharging = false,
    this.requiresDeviceIdle = false,
  });

  /// Returns a clamped schedule for Android (enforces 15-minute minimum).
  OsBackgroundTaskSchedule clampedForAndroid() {
    final clampedFreq =
        frequency < androidMinInterval ? androidMinInterval : frequency;
    if (clampedFreq == frequency) return this;
    return OsBackgroundTaskSchedule(
      frequency: clampedFreq,
      initialDelay: initialDelay,
      networkConstraint: networkConstraint,
      requiresCharging: false, // Not supported on Android
      requiresDeviceIdle: requiresDeviceIdle,
    );
  }

  /// Converts this schedule to workmanager `Constraints`.
  Constraints toWorkmanagerConstraints() {
    final networkType = switch (networkConstraint) {
      OsNetworkConstraint.connected => NetworkType.connected,
      OsNetworkConstraint.unmetered => NetworkType.unmetered,
      OsNetworkConstraint.none => NetworkType.not_required,
    };

    return Constraints(
      networkType: networkType,
      requiresDeviceIdle: requiresDeviceIdle ? true : null,
      requiresCharging: requiresCharging ? true : null,
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
  /// On Android this is always true for `PeriodicWorkRequest`.
  /// On iOS this depends on the background mode registration.
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

/// Registered task handler registry.
///
/// Maps task identifiers to their handler functions. The [callbackDispatcher]
/// uses this registry to dispatch tasks.
final Map<String, OsBackgroundTaskHandler> _osTaskHandlers = {};

/// The background isolate entry point for workmanager.
///
/// Registered with `@pragma('vm:entry-point')` so the Dart VM preserves it
/// as a valid entry point for background isolate spawning.
///
/// **Do NOT call this directly.** It is invoked by workmanager when the OS
/// schedules a background execution.
@pragma('vm:entry-point')
void osBackgroundTaskCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final handler = _osTaskHandlers[task];
    if (handler != null) {
      await handler();
      return true;
    }
    debugPrint(
      '[OsBackgroundTask] No handler registered for task: $task',
    );
    return false;
  });
}

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
/// ### Web
/// - Not supported. [OsBackgroundTask.register] is a no-op on web,
///   and [OsBackgroundTask.initialize] completes immediately.
///
/// ## Usage
///
/// ```dart
/// // In main() before runApp():
/// await OsBackgroundTask.initialize();
///
/// // Register a task:
/// OsBackgroundTask.register(
///   OsBackgroundTaskDescriptor(
///     identifier: 'com.app.sync-data',
///     taskName: 'SyncData',
///     schedule: OsBackgroundTaskSchedule(
///       frequency: Duration(minutes: 30),
///       networkConstraint: OsNetworkConstraint.connected,
///     ),
///   ),
///   () async {
///     // Your background work here
///     final data = await fetchData();
///     await saveLocally(data);
///   },
/// );
/// ```
class OsBackgroundTask {
  /// Whether workmanager has been initialized.
  static bool _initialized = false;

  /// Registered descriptors for bookkeeping.
  static final Map<String, OsBackgroundTaskDescriptor> _registrations = {};

  OsBackgroundTask._();

  /// Initialize the workmanager plugin.
  ///
  /// Call this once in `main()` before `runApp()`. On web, this is a no-op.
  ///
  /// ```dart
  /// Future<void> main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await OsBackgroundTask.initialize();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<bool> initialize() async {
    if (kIsWeb) {
      debugPrint('[OsBackgroundTask] Web platform — initialize is a no-op.');
      return true;
    }

    if (_initialized) {
      debugPrint('[OsBackgroundTask] Already initialized.');
      return true;
    }

    try {
      await Workmanager().initialize(
        osBackgroundTaskCallbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      _initialized = true;
      debugPrint('[OsBackgroundTask] Initialized successfully.');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[OsBackgroundTask] Initialization failed: $e');
      debugPrint('[OsBackgroundTask] $stackTrace');
      return false;
    }
  }

  /// Register a periodic background task with the OS scheduler.
  ///
  /// On web, this is a no-op (no OS background scheduling available).
  ///
  /// The [handler] must be a top-level function or static method reference.
  /// Closures capturing context from the main isolate may not work
  /// correctly on Android (which spawns a separate isolate).
  ///
  /// Returns `true` if registration succeeded (or is a no-op on web).
  static Future<bool> register(
    OsBackgroundTaskDescriptor descriptor,
    OsBackgroundTaskHandler handler,
  ) async {
    if (kIsWeb) {
      debugPrint(
        '[OsBackgroundTask] Web platform — register is a no-op for '
        'task: ${descriptor.identifier}',
      );
      return true;
    }

    if (!_initialized) {
      debugPrint(
        '[OsBackgroundTask] Not initialized. Call initialize() first. '
        'Task: ${descriptor.identifier}',
      );
      return false;
    }

    // Register the handler in the dispatch map.
    _osTaskHandlers[descriptor.identifier] = handler;
    _registrations[descriptor.identifier] = descriptor;

    // Determine the correct frequency based on platform.
    final frequency = defaultTargetPlatform == TargetPlatform.android
        ? descriptor.schedule.clampedForAndroid().frequency
        : descriptor.schedule.frequency;

    try {
      await Workmanager().registerPeriodicTask(
        descriptor.identifier,
        descriptor.taskName,
        frequency: frequency,
        constraints: descriptor.schedule.toWorkmanagerConstraints(),
        initialDelay: descriptor.schedule.initialDelay
            ? const Duration(seconds: 1)
            : Duration.zero,
        existingWorkPolicy: ExistingWorkPolicy.keep,
        tag: descriptor.identifier,
      );
      debugPrint(
        '[OsBackgroundTask] Registered: ${descriptor.identifier} '
        '(${descriptor.taskName}) every ${frequency.inMinutes} min',
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint(
        '[OsBackgroundTask] Failed to register: ${descriptor.identifier} — $e',
      );
      debugPrint('[OsBackgroundTask] $stackTrace');
      return false;
    }
  }

  /// Cancel a previously registered background task.
  ///
  /// Returns `true` if cancellation succeeded.
  static Future<bool> cancel(String identifier) async {
    if (kIsWeb) return true;

    _osTaskHandlers.remove(identifier);
    _registrations.remove(identifier);

    try {
      await Workmanager().cancelByTag(identifier);
      debugPrint('[OsBackgroundTask] Cancelled: $identifier');
      return true;
    } catch (e) {
      debugPrint('[OsBackgroundTask] Failed to cancel: $identifier — $e');
      return false;
    }
  }

  /// Cancel all registered background tasks.
  ///
  /// Returns `true` if all cancellations succeeded.
  static Future<bool> cancelAll() async {
    if (kIsWeb) return true;

    _osTaskHandlers.clear();
    _registrations.clear();

    try {
      await Workmanager().cancelAll();
      debugPrint('[OsBackgroundTask] Cancelled all tasks.');
      return true;
    } catch (e) {
      debugPrint('[OsBackgroundTask] Failed to cancel all — $e');
      return false;
    }
  }

  /// Check whether a task with the given [identifier] is currently registered.
  static bool isRegistered(String identifier) =>
      _registrations.containsKey(identifier);

  /// List all currently registered task identifiers.
  static List<String> get registeredIdentifiers =>
      _registrations.keys.toList();

  /// Get the descriptor for a registered task, or null if not registered.
  static OsBackgroundTaskDescriptor? getDescriptor(String identifier) =>
      _registrations[identifier];

  /// Reset internal state. For testing purposes only.
  @visibleForTesting
  static void reset() {
    _initialized = false;
    _osTaskHandlers.clear();
    _registrations.clear();
  }
}
