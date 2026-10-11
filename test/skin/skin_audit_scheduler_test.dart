// Issue #1102 — SkinAuditScheduler: subscribe-don't-poll (pilot lesson 5).
// The auditor marks dirty on real signals (dependency change, route
// events); the audit runs only when dirty — it NEVER self-reschedules,
// so pumpAndSettle can settle.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/skin_audit_scheduler.dart';

void main() {
  group('issue #1102 — SkinAuditScheduler', () {
    test('starts clean and not dirty', () {
      final scheduler = SkinAuditScheduler();
      expect(scheduler.isDirty, isFalse);
      expect(scheduler.auditCount, 0);
    });

    test('markDirty makes the next consumeDirty return true exactly once', () {
      final scheduler = SkinAuditScheduler();
      scheduler.markDirty('view-dependency-changed');
      expect(scheduler.isDirty, isTrue);
      // One-shot: the first consume schedules ONE audit…
      expect(scheduler.consumeDirty(), isTrue);
      expect(scheduler.isDirty, isFalse);
      // …and the second consume is quiet — no polling loop.
      expect(scheduler.consumeDirty(), isFalse);
    });

    test('repeated markDirty collapses into one audit (coalescing)', () {
      final scheduler = SkinAuditScheduler();
      scheduler
        ..markDirty('didChangeDependencies')
        ..markDirty('didUpdateWidget')
        ..markDirty('route-push');
      expect(scheduler.consumeDirty(), isTrue);
      expect(scheduler.consumeDirty(), isFalse);
    });

    test('consumeDirty counts the audits that actually ran', () {
      final scheduler = SkinAuditScheduler();
      scheduler.markDirty('a');
      scheduler.consumeDirty();
      scheduler.markDirty('b');
      scheduler.consumeDirty();
      scheduler.consumeDirty();
      expect(scheduler.auditCount, 2);
    });

    test('the dirty reasons are recorded (diagnostics for the banner)', () {
      final scheduler = SkinAuditScheduler();
      scheduler
        ..markDirty('view-dependency-changed')
        ..markDirty('route-push');
      expect(scheduler.dirtyReasons, contains('view-dependency-changed'));
      expect(scheduler.dirtyReasons, contains('route-push'));
    });

    test('no signal, no audit: a quiet tree never schedules work', () {
      final scheduler = SkinAuditScheduler();
      for (var i = 0; i < 10; i++) {
        // Ten quiet frames — the pilot's self-rescheduling auditor would
        // have run ten audits; the productized scheduler runs zero.
        expect(scheduler.consumeDirty(), isFalse);
      }
      expect(scheduler.auditCount, 0);
    });

    test('reset clears counters and reasons', () {
      final scheduler = SkinAuditScheduler();
      scheduler
        ..markDirty('x')
        ..consumeDirty()
        ..reset();
      expect(scheduler.isDirty, isFalse);
      expect(scheduler.auditCount, 0);
      expect(scheduler.dirtyReasons, isEmpty);
    });
  });
}
