/// App-update seam: version check + update flow (pairs with `zfa
/// self-update` on the CLI side).
library;

import 'dart:convert';

/// The outcome of an update check.
class UpdateInfo {
  /// The currently running version.
  final String currentVersion;

  /// The latest available version.
  final String latestVersion;

  /// Whether [latestVersion] is newer than [currentVersion].
  final bool isUpdateAvailable;

  /// Optional release notes for the available update.
  final String? releaseNotes;

  /// Optional download/landing URL for the update.
  final String? downloadUrl;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.isUpdateAvailable,
    this.releaseNotes,
    this.downloadUrl,
  });

  Map<String, dynamic> toJson() => {
    'currentVersion': currentVersion,
    'latestVersion': latestVersion,
    'isUpdateAvailable': isUpdateAvailable,
    if (releaseNotes != null) 'releaseNotes': releaseNotes,
    if (downloadUrl != null) 'downloadUrl': downloadUrl,
  };

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
    currentVersion: json['currentVersion'] as String,
    latestVersion: json['latestVersion'] as String,
    isUpdateAvailable: json['isUpdateAvailable'] as bool,
    releaseNotes: json['releaseNotes'] as String?,
    downloadUrl: json['downloadUrl'] as String?,
  );

  /// Convenience for feed/fetch responses.
  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateInfo &&
          other.currentVersion == currentVersion &&
          other.latestVersion == latestVersion &&
          other.isUpdateAvailable == isUpdateAvailable &&
          other.releaseNotes == releaseNotes &&
          other.downloadUrl == downloadUrl;

  @override
  int get hashCode =>
      Object.hash(currentVersion, latestVersion, isUpdateAvailable);
}

/// Recoverable, typed app-update error.
class AppUpdateException implements Exception {
  /// Machine-readable reason, stable across releases.
  final String code;

  /// Human-readable description.
  final String message;

  const AppUpdateException(this.code, this.message);

  /// The update check failed (network, store unavailable).
  factory AppUpdateException.checkFailed(String detail) =>
      AppUpdateException('check_failed', 'Update check failed: $detail');

  @override
  String toString() => 'AppUpdateException($code): $message';
}

/// The app-update contract.
abstract class AppUpdatePort {
  /// Checks the store/feed for updates relative to [currentVersion].
  Future<UpdateInfo> checkForUpdates(String currentVersion);

  /// Launches the platform update flow (store page or in-app download);
  /// returns whether the flow could be started.
  Future<bool> performUpdate(UpdateInfo info);
}

/// Pure-Dart default adapter: scripted check results.
class InMemoryAppUpdateAdapter implements AppUpdatePort {
  /// The [UpdateInfo] the next [checkForUpdates] returns. Defaults to
  /// "up to date" at 0.0.0.
  UpdateInfo nextInfo = const UpdateInfo(
    currentVersion: '0.0.0',
    latestVersion: '0.0.0',
    isUpdateAvailable: false,
  );

  /// Whether [performUpdate] reports success.
  bool updateLaunchable = true;

  /// Infos passed to [performUpdate] (introspection).
  final List<UpdateInfo> updatesLaunched = [];

  @override
  Future<UpdateInfo> checkForUpdates(String currentVersion) async {
    // The adapter reports against the caller's version, not the scripted
    // one, so version comparisons stay honest.
    if (nextInfo.currentVersion == currentVersion) {
      return nextInfo;
    }
    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: nextInfo.latestVersion,
      isUpdateAvailable:
          nextInfo.isUpdateAvailable &&
          currentVersion != nextInfo.latestVersion,
      releaseNotes: nextInfo.releaseNotes,
      downloadUrl: nextInfo.downloadUrl,
    );
  }

  @override
  Future<bool> performUpdate(UpdateInfo info) async {
    updatesLaunched.add(info);
    return updateLaunchable;
  }
}
