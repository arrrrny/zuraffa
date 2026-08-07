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
/// ### Web
/// - Not supported. [OsBackgroundTask.register] is a no-op on web,
///   and [OsBackgroundTask.initialize] completes immediately.
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
/// ## Usage
///
/// ```dart
/// // 1. Define your top-level dispatcher (in your app code, NOT zuraffa):
/// @pragma('vm:entry-point')
/// void myAppCallbackDispatcher() {
///   OsBackgroundTask.dispatch({
///     'com.app.sync-data': SyncDataTaskUseCase.callbackHandler,
///     'com.app.cleanup': CleanupTaskUseCase.callbackHandler,
///     // Add all your task handlers here as compile-time references
///   });
/// }
///
/// // 2. In main() before runApp():
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await OsBackgroundTask.initialize(
///     callbackDispatcher: myAppCallbackDispatcher,
///   );
///   runApp(MyApp());
/// }
///
/// // 3. Register tasks (the map in your dispatcher defines which handlers exist):
/// final syncTask = SyncDataTaskUseCase(dataService);
/// await syncTask.register(); // Uses descriptor.identifier
/// ```
class OsBackgroundTask {
  /// Whether workmanager has been initialized.
  static bool _initialized = false;

  /// Registered descriptors for bookkeeping (main isolate only).
  ///
  /// This is NOT used for background dispatch — it's for foreground
  /// bookkeeping only (e.g., [isRegistered], [getDescriptor]).
  static final Map<String, OsBackgroundTaskDescriptor> _registrations = {};

  OsBackgroundTask._();

  /// Initialize the workmanager plugin with your app's callback dispatcher.
  ///
  /// **REQUIRED**: [callbackDispatcher] must be a top-level function
  /// annotated with `@pragma('vm:entry-point')` that calls [dispatch]
  /// with a compile-time map of your task handlers.
  ///
  /// On web, this is a no-op (callback dispatcher is ignored).
  ///
  /// ```dart
  /// @pragma('vm:entry-point')
  /// void myAppCallbackDispatcher() {
  ///   OsBackgroundTask.dispatch({
  ///     'com.app.task1': Task1UseCase.callbackHandler,
  ///     'com.app.task2': Task2UseCase.callbackHandler,
  ///   });
  /// }
  ///
  /// Future<void> main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await OsBackgroundTask.initialize(
  ///     callbackDispatcher: myAppCallbackDispatcher,
  ///   );
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<bool> initialize({
    required void Function() callbackDispatcher,
  }) async {
    if (kIsWeb) {
      debugPrint('[OsBackgroundTask] Web platform — initialize is a no-op.');
      _initialized = true;
      return true;
    }

    if (_initialized) {
      debugPrint('[OsBackgroundTask] Already initialized.');
      return true;
    }

    try {
      await Workmanager().initialize(
        callbackDispatcher,
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

  /// Dispatch a background task to its handler.
  ///
  /// **Call this from your app's top-level callback dispatcher function**,
  /// passing a compile-time map literal of task identifiers to handlers.
  ///
  /// This runs inside `Workmanager().executeTask(...)` and returns a
  /// [Future<bool>] indicating success/failure (used by workmanager for retry).
  ///
  /// ```dart
  /// @pragma('vm:entry-point')
  /// void myAppCallbackDispatcher() {
  ///   OsBackgroundTask.dispatch({
  ///     'com.app.sync-data': SyncDataTaskUseCase.callbackHandler,
  ///     'com.app.cleanup': CleanupTaskUseCase.callbackHandler,
  ///   });
  /// }
  /// ```
  static void dispatch(Map<String, OsBackgroundTaskHandler> handlers) {
    Workmanager().executeTask((task, inputData) async {
      final handler = handlers[task];
      if (handler != null) {
        try {
          await handler();
          return true;
        } catch (e, stackTrace) {
          debugPrint(
            '[OsBackgroundTask] Handler for task "$task" failed: $e',
          );
          debugPrint('[OsBackgroundTask] $stackTrace');
          // Return false so workmanager can retry
          return false;
        }
      }
      debugPrint(
        '[OsBackgroundTask] No handler registered for task: $task',
      );
      return false;
    });
  }

  /// Register a periodic background task with the OS scheduler.
  ///
  /// On web, this is a no-op (no OS background scheduling available).
  ///
  /// **IMPORTANT**: Before calling this, ensure your app's callback dispatcher
  /// (passed to [initialize]) includes an entry for [descriptor.identifier]
  /// in its handlers map. The framework does NOT track handlers for you —
  /// the handler map must be written directly in your dispatcher's source code.
  ///
  /// Returns `true` if registration succeeded (or is a no-op on web).
  static Future<bool> register(
    OsBackgroundTaskDescriptor descriptor,
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

    _registrations[descriptor.identifier] = descriptor;

    // Determine the correct schedule based on platform (clamp on Android).
    final effectiveSchedule = defaultTargetPlatform == TargetPlatform.android
        ? descriptor.schedule.clampedForAndroid()
        : descriptor.schedule;

    try {
      await Workmanager().registerPeriodicTask(
        descriptor.identifier,
        descriptor.taskName,
        frequency: effectiveSchedule.frequency,
        constraints: effectiveSchedule.toWorkmanagerConstraints(),
        initialDelay: effectiveSchedule.initialDelay
            ? const Duration(seconds: 1)
            : Duration.zero,
        existingWorkPolicy: ExistingWorkPolicy.keep,
        tag: descriptor.identifier,
      );
      debugPrint(
        '[OsBackgroundTask] Registered: ${descriptor.identifier} '
        '(${descriptor.taskName}) every ${effectiveSchedule.frequency.inMinutes} min',
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint(
        '[OsBackgroundTask] Failed to register: ${descriptor.identifier} — $e',
      );
      debugPrint('[OsBackgroundTask] $stackTrace');
      // Clean up failed registration
      _registrations.remove(descriptor.identifier);
      return false;
    }
  }

  /// Cancel a previously registered background task.
  ///
  /// Returns `true` if cancellation succeeded.
  static Future<bool> cancel(String identifier) async {
    if (kIsWeb) return true;

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
    _registrations.clear();
  }
}
