import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// App-update built-in: scripted adapter, honest version comparison,
/// no-op update guard, JSON round-trip of UpdateInfo.
void main() {
  group('InMemoryAppUpdateAdapter', () {
    test('reports against the caller version, not the scripted one',
        () async {
      final port = InMemoryAppUpdateAdapter()
        ..nextInfo = const UpdateInfo(
          currentVersion: '1.0.0',
          latestVersion: '1.2.0',
          isUpdateAvailable: true,
          releaseNotes: 'Bug fixes',
          downloadUrl: 'https://example.test/dl',
        );

      // Caller on 1.1.0 (scripted current is 1.0.0): still an update.
      final info = await port.checkForUpdates('1.1.0');

      expect(info.currentVersion, '1.1.0');
      expect(info.latestVersion, '1.2.0');
      expect(info.isUpdateAvailable, isTrue);
      expect(info.releaseNotes, 'Bug fixes');

      // Caller already on the latest: not an update.
      final latest = await port.checkForUpdates('1.2.0');
      expect(latest.isUpdateAvailable, isFalse);
    });

    test('performUpdate records the info and reports launchability',
        () async {
      final port = InMemoryAppUpdateAdapter();
      const info = UpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '1.1.0',
        isUpdateAvailable: true,
      );

      expect(await port.performUpdate(info), isTrue);
      expect(port.updatesLaunched, [info]);

      port.updateLaunchable = false;
      expect(await port.performUpdate(info), isFalse);
    });
  });

  group('UpdateInfo JSON round-trip', () {
    test('toJson/fromJson/encode preserve every field', () {
      const info = UpdateInfo(
        currentVersion: '1.0.0',
        latestVersion: '1.1.0',
        isUpdateAvailable: true,
        releaseNotes: 'Notes',
        downloadUrl: 'https://example.test/dl',
      );

      final restored = UpdateInfo.fromJson(info.toJson());
      expect(restored, info);
      expect(UpdateInfo.fromJson(jsonDecode(info.encode())
          as Map<String, dynamic>), info);
    });
  });

  group('AppUpdateService', () {
    test('isUpdateAvailable + performUpdate launch the real flow',
        () async {
      final port = InMemoryAppUpdateAdapter()
        ..nextInfo = const UpdateInfo(
          currentVersion: '1.0.0',
          latestVersion: '2.0.0',
          isUpdateAvailable: true,
        );
      final service = AppUpdateService(port: port, currentVersion: '1.0.0');

      expect(await service.isUpdateAvailable, isTrue);

      final info = await service.checkForUpdates();
      expect(await service.performUpdate(info), isTrue);
      expect(port.updatesLaunched, hasLength(1));
    });

    test('performUpdate on a no-update info is a no-op (false, no throw)',
        () async {
      final port = InMemoryAppUpdateAdapter();
      final service = AppUpdateService(port: port, currentVersion: '1.0.0');

      final info = await service.checkForUpdates();
      expect(info.isUpdateAvailable, isFalse);

      expect(await service.performUpdate(info), isFalse);
      expect(port.updatesLaunched, isEmpty,
          reason: 'same-version "updates" never reach the platform');
    });

    test('registerAppUpdateDependencies wires port + service with the '
        'app version', () async {
      final getIt = GetIt.asNewInstance();
      registerAppUpdateDependencies(getIt, currentVersion: '3.1.4');

      final service = getIt<AppUpdateService>();
      final info = await service.checkForUpdates();

      expect(info.currentVersion, '3.1.4');
      expect(info.isUpdateAvailable, isFalse,
          reason: 'default scripted feed is up-to-date');
    });
  });
}
