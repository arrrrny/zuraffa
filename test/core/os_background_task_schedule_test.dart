import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('OsBackgroundTaskSchedule', () {
    test('recommended default has 15-minute frequency and no constraints', () {
      const recommended = OsBackgroundTaskSchedule.recommended;
      expect(recommended.frequency, equals(const Duration(minutes: 15)));
      expect(
          recommended.networkConstraint, equals(OsNetworkConstraint.none));
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

    test('hashCode is consistent with equality', () {
      const a = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 15),
        networkConstraint: OsNetworkConstraint.connected,
        requiresCharging: true,
      );
      const b = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 15),
        networkConstraint: OsNetworkConstraint.connected,
        requiresCharging: true,
      );

      expect(a.hashCode, equals(b.hashCode));
    });

    test('different constraints produce different hashCodes', () {
      const a = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 15),
        networkConstraint: OsNetworkConstraint.none,
      );
      const b = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 15),
        networkConstraint: OsNetworkConstraint.connected,
      );

      expect(a.hashCode, isNot(equals(b.hashCode)));
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
      expect(
          descriptor.schedule, equals(OsBackgroundTaskSchedule.recommended));
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

    test('default schedule has correct defaults', () {
      const descriptor = OsBackgroundTaskDescriptor(
        identifier: 'com.app.task',
        taskName: 'Task',
      );
      expect(descriptor.schedule.frequency, equals(const Duration(minutes: 15)));
      expect(descriptor.schedule.initialDelay, isFalse);
      expect(descriptor.schedule.requiresCharging, isFalse);
      expect(descriptor.schedule.requiresDeviceIdle, isFalse);
      expect(descriptor.schedule.networkConstraint, OsNetworkConstraint.none);
    });

    test('all fields can be customized', () {
      const schedule = OsBackgroundTaskSchedule(
        frequency: Duration(minutes: 30),
        initialDelay: true,
        networkConstraint: OsNetworkConstraint.unmetered,
        requiresCharging: true,
        requiresDeviceIdle: true,
      );
      const descriptor = OsBackgroundTaskDescriptor(
        identifier: 'com.app.custom',
        taskName: 'CustomTask',
        schedule: schedule,
        runWhenAppTerminated: false,
      );
      expect(descriptor.schedule.frequency, equals(const Duration(minutes: 30)));
      expect(descriptor.schedule.initialDelay, isTrue);
      expect(descriptor.schedule.networkConstraint,
          OsNetworkConstraint.unmetered);
      expect(descriptor.schedule.requiresCharging, isTrue);
      expect(descriptor.schedule.requiresDeviceIdle, isTrue);
      expect(descriptor.runWhenAppTerminated, isFalse);
    });
  });

  group('OsNetworkConstraint', () {
    test('has exactly three values', () {
      expect(OsNetworkConstraint.values.length, equals(3));
      expect(OsNetworkConstraint.values, contains(OsNetworkConstraint.none));
      expect(
          OsNetworkConstraint.values, contains(OsNetworkConstraint.connected));
      expect(
          OsNetworkConstraint.values, contains(OsNetworkConstraint.unmetered));
    });
  });
}
