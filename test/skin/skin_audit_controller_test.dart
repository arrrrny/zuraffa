// Issue #1102 — SkinAuditController: the pure bus core the debug chrome
// renders. Publish/clear with change detection, bounded history.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/skin_audit_controller.dart';
import 'package:zuraffa/src/skin/skin_violation.dart';

void main() {
  group('issue #1102 — SkinAuditController', () {
    test('starts clean: no violations, no listeners fired', () {
      final controller = SkinAuditController();
      expect(controller.violations, isEmpty);
      expect(controller.hasViolations, isFalse);
    });

    test('publish replaces the live set and notifies listeners', () {
      final controller = SkinAuditController();
      var notified = 0;
      controller.addListener(() => notified++);
      final changed = controller.publish([
        SkinViolation.widget(
          rowId: 'google-text',
          requirement: 'r',
          message: 'm',
        ),
      ]);
      expect(changed, isTrue);
      expect(controller.hasViolations, isTrue);
      expect(controller.violations, hasLength(1));
      expect(notified, 1);
    });

    test(
      'publish with an empty list clears the banner (pilot: revert + hot reload)',
      () {
        final controller = SkinAuditController();
        controller.publish([
          SkinViolation.widget(
            rowId: 'google-text',
            requirement: 'r',
            message: 'm',
          ),
        ]);
        final changed = controller.publish(const []);
        // Revert + hot reload -> banner clears on the next frame.
        expect(changed, isTrue);
        expect(controller.hasViolations, isFalse);
      },
    );

    test(
      'publishing the SAME violations reports no change (no banner churn)',
      () {
        final controller = SkinAuditController();
        final violations = [
          SkinViolation.widget(
            rowId: 'google-text',
            requirement: 'r',
            message: 'm',
          ),
        ];
        controller.publish(violations);
        var notified = 0;
        controller.addListener(() => notified++);
        final changed = controller.publish(violations);
        expect(changed, isFalse);
        expect(notified, 0);
      },
    );

    test('clear() empties the live set with change detection', () {
      final controller = SkinAuditController();
      controller.publish([
        SkinViolation.widget(rowId: 'a', requirement: 'r', message: 'm'),
      ]);
      final changedFirst = controller.clear();
      expect(changedFirst, isTrue);
      expect(controller.hasViolations, isFalse);
      // Clearing an already-clean bus is a no-op.
      expect(controller.clear(), isFalse);
    });

    test('history keeps what was published, bounded', () {
      final controller = SkinAuditController(historyLimit: 3);
      for (var i = 0; i < 5; i++) {
        controller.publish([
          SkinViolation.widget(rowId: 'row-$i', requirement: 'r', message: 'm'),
        ]);
      }
      expect(controller.history, hasLength(3));
      // Most recent first.
      expect(controller.history.first.first.rowId, 'row-4');
      expect(controller.history.last.first.rowId, 'row-2');
    });

    test('removeListener stops notifications', () {
      final controller = SkinAuditController();
      var notified = 0;
      void listener() => notified++;
      controller
        ..addListener(listener)
        ..publish([
          SkinViolation.route(
            rowId: 'x',
            requirement: 'r',
            message: 'm',
            route: 'x',
          ),
        ])
        ..removeListener(listener)
        ..publish(const []);
      expect(notified, 1);
    });

    test('violations list is unmodifiable from outside', () {
      final controller = SkinAuditController();
      controller.publish([
        SkinViolation.widget(rowId: 'a', requirement: 'r', message: 'm'),
      ]);
      expect(
        () => controller.violations.add(
          SkinViolation.widget(rowId: 'b', requirement: 'r', message: 'm'),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('dispose drops listeners', () {
      final controller = SkinAuditController();
      var notified = 0;
      controller.addListener(() => notified++);
      controller.dispose();
      controller.publish([
        SkinViolation.widget(rowId: 'a', requirement: 'r', message: 'm'),
      ]);
      expect(notified, 0);
    });
  });
}
