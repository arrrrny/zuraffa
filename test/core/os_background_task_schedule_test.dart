import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('OsBackgroundTaskSchedule', () {
    test('recommended default has 15-minute frequency and no constraints', () {
      const recommended = OsBackgroundTaskSchedule.recommended;
      expect(recommended.frequency, equals(const Duration(minutes: 15)));
      expect(recommended.networkConstraint, equals(OsNetworkConstraint.none));
      expect(recommended.requiresCharging, isFalse);
      expect(recommended.requiresDeviceIdle, isFalse);
      expect(recommended.initialDelay, isFalse);
    });

    test('clampedForAndroid enforces 15-minute minimum', () {
      const short = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 5),
      );
      final clamped = short.clampedForAndroid();
      expect(clamped.frequency, equals(const Duration(minutes: 15)));
    });

    test('clampedForAndroid leaves 15+ minute schedules unchanged', () {
      const normal = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 30),
      );
      final clamped = normal.clampedForAndroid();
      expect(clamped, same(normal));
    });

    test('clampedForAndroid clamps to exactly 15 minutes at boundary', () {
      const exact = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 15),
      );
      final clamped = exact.clampedForAndroid();
      expect(clamped, same(exact));
    });

    test('clampedForAndroid removes requiresCharging (not supported)', () {
      const schedule = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 5),
        requiresCharging: true,
        requiresDeviceIdle: true,
      );
      final clamped = schedule.clampedForAndroid();
      expect(clamped.frequency, equals(const Duration(minutes: 15)));
      expect(clamped.requiresCharging, isFalse);
      expect(clamped.requiresDeviceIdle, isTrue);
    });

    group('toWorkmanagerConstraints', () {
      test('none constraint maps to not_required', () {
        const schedule = OsBackgroundTaskSchedule(
          frequency: Duration(minutes: 15),
        );
        final constraints = schedule.toWorkmanagerConstraints();
        expect(constraints.networkType, equals(NetworkType.not_required));
      });

      test('connected constraint maps to NetworkType.connected', () {
        const schedule = OsBackgroundTaskSchedule(
          frequency: Duration(minutes: 15),
          networkConstraint: OsNetworkConstraint.connected,
        );
        final constraints = schedule.toWorkmanagerConstraints();
        expect(constraints.networkType, equals(NetworkType.connected));
      });

      test('unmetered constraint maps to NetworkType.unmetered', () {
        const schedule = OsBackgroundTaskSchedule(
          frequency: Duration(minutes: 15),
          networkConstraint: OsNetworkConstraint.unmetered,
        );
        final constraints = schedule.toWorkmanagerConstraints();
        expect(constraints.networkType, equals(NetworkType.unmetered));
      });

      test('requiresDeviceIdle is propagated', () {
        const schedule = OsBackgroundTaskSchedule(
          frequency: Duration(minutes: 15),
          requiresDeviceIdle: true,
        );
        final constraints = schedule.toWorkmanagerConstraints();
        expect(constraints.requiresDeviceIdle, isTrue);
      });

      test('requiresCharging is propagated', () {
        const schedule = OsBackgroundTaskSchedule(
          frequency: Duration(minutes: 15),
          requiresCharging: true,
        );
        final constraints = schedule.toWorkmanagerConstraints();
        expect(constraints.requiresCharging, isTrue);
      });
    });

    test('equality works correctly', () {
      const a = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 15),
        networkConstraint: OsNetworkConstraint.connected,
      );
      const b = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 15),
        networkConstraint: OsNetworkConstraint.connected,
      );
      const c = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 30),
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('OsBackgroundTaskDescriptor', () {
    test('has required fields', () {
      const descriptor = OsBackgroundTaskDescriptor(
        identifier: 'com.app.sync',
        taskName: 'SyncData',
      );
      expect(descriptor.identifier, equals('com.app.sync'));
      expect(descriptor.taskName, equals('SyncData'));
      expect(descriptor.schedule, equals(OsBackgroundTaskSchedule.recommended));
      expect(descriptor.runWhenAppTerminated, isTrue);
    });

    test('custom schedule is preserved', () {
      const schedule = OsBackgroundTaskSchedule(
        frequency: Duration(hours: 1),
        networkConstraint: OsNetworkConstraint.connected,
      );
      const descriptor = OsBackgroundTaskDescriptor(
        identifier: 'com.app.sync',
        taskName: 'SyncData',
        schedule: schedule,
      );
      expect(descriptor.schedule.frequency, equals(const Duration(hours: 1)));
      expect(
        descriptor.schedule.networkConstraint,
        equals(OsNetworkConstraint.connected),
      );
    });
  });
}
