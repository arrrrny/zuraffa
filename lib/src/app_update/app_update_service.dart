import 'package:get_it/get_it.dart';

import 'app_update.dart';

export 'app_update.dart';

/// App-facing update facade: check, gate, and launch.
///
/// ```dart
/// final updates = AppUpdateService(currentVersion: '1.2.3');
/// final info = await updates.checkForUpdates();
/// if (info.isUpdateAvailable) {
///   await updates.performUpdate(info);
/// }
/// ```
class AppUpdateService {
  /// The platform adapter (or the in-memory default in tests).
  final AppUpdatePort port;

  /// The running app's version — the baseline every check compares
  /// against.
  final String currentVersion;

  AppUpdateService({AppUpdatePort? port, this.currentVersion = '0.0.0'})
    : port = port ?? InMemoryAppUpdateAdapter();

  /// Checks for an update relative to [currentVersion].
  Future<UpdateInfo> checkForUpdates() => port.checkForUpdates(currentVersion);

  /// Convenience: check + report availability in one call.
  Future<bool> get isUpdateAvailable async =>
      (await checkForUpdates()).isUpdateAvailable;

  /// Launches the platform update flow for [info]; returns whether the
  /// flow could be started. A no-op (false, no throw) when [info]
  /// reports no update available — callers cannot accidentally "update"
  /// to the same version.
  Future<bool> performUpdate(UpdateInfo info) async {
    if (!info.isUpdateAvailable) return false;
    return port.performUpdate(info);
  }
}

/// Registers the app-update stack onto [getIt].
void registerAppUpdateDependencies(
  GetIt getIt, {
  AppUpdatePort? port,
  String currentVersion = '0.0.0',
}) {
  getIt
    ..registerLazySingleton<AppUpdatePort>(
      () => port ?? InMemoryAppUpdateAdapter(),
    )
    ..registerLazySingleton<AppUpdateService>(
      () => AppUpdateService(
        port: getIt<AppUpdatePort>(),
        currentVersion: currentVersion,
      ),
    );
}
