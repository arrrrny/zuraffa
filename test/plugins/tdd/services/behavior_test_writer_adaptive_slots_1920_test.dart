/// Issue #1920 — the widget-lane template gains a slot-aware harness.
///
/// `zfa tdd run-skin` conformance mode (spec 1005) accepts a behavior only
/// when the GREEN transcript carries one `skin-event: behavior=<id>
/// slot=<slot>` line per declared `adaptive_slots` entry. Before this the
/// generated widget test imported `material.dart` only (no
/// `debugDefaultTargetPlatformOverride`), had no per-slot loop, and the
/// documented release route (`addTearDown`) fired AFTER the framework's
/// foundation-debug invariant check.
///
/// These tests pin the emitted shape:
///   - slot-aware: foundation import, a `for` loop over the declared
///     slots, a per-slot pin, the `skin-event` print after the pump, and a
///     `finally` release INSIDE the body;
///   - legacy: the template stays byte-identical (no foundation import,
///     no loop) when no slots are declared;
///   - non-widget kinds ignore the slots.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';

void main() {
  Future<String> render(
    Behavior behavior, {
    List<String> adaptiveSlots = const <String>[],
  }) async {
    final dir = Directory.systemTemp.createTempSync('skin_slots_1920_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final testPath = p.join(dir.path, 'test', 'tdd', 'w1_test.dart');
    final subjectPath = p.join(dir.path, 'lib', 'tdd', 'w1_subject.dart');
    await BehaviorTestWriter(
      adaptiveSlots: adaptiveSlots,
    ).write(behavior: behavior, testPath: testPath, subjectPath: subjectPath);
    return File(testPath).readAsString();
  }

  Behavior widget({String id = 'W1', String target = 'loginView'}) => Behavior(
    id: id,
    feature: '1920-skin-slots',
    kind: BehaviorKind.widget,
    description: "renders the 'Home' label after sign-in.",
    sourceCriterion: 'SC-001',
    target: target,
  );

  group('issue #1920: slot-aware widget harness', () {
    test('emits the foundation import channel the slot pin needs', () async {
      final content = await render(
        widget(),
        adaptiveSlots: const ['mobile', 'ios', 'android', 'macos'],
      );
      expect(
        content,
        contains("import 'package:flutter/foundation.dart';"),
        reason:
            'debugDefaultTargetPlatformOverride lives in foundation.dart; '
            'material.dart does not re-export it (issue #1920)',
      );
    });

    test('wraps the test body in a loop over the declared slots', () async {
      final content = await render(
        widget(),
        adaptiveSlots: const ['mobile', 'ios', 'android', 'macos'],
      );
      expect(
        content,
        contains(
          "for (final slot in const <String>['mobile', 'ios', 'android', "
          "'macos'])",
        ),
      );
      expect(content, contains('_pinSkinSlot(tester, slot);'));
    });

    test('prints one skin-event per slot after the render', () async {
      final content = await render(
        widget(),
        adaptiveSlots: const ['mobile', 'macos'],
      );
      expect(
        content,
        contains("print('skin-event: behavior=W1 slot=\$slot');"),
      );
      final pump = content.indexOf('pumpAndSettle()');
      final event = content.indexOf('skin-event: behavior=W1');
      expect(
        event,
        greaterThan(pump),
        reason:
            'the event line must describe a RENDERED slot — it is printed '
            'after the pump, the exact line the conformance gate reads',
      );
    });

    test('releases the pin in a finally INSIDE the test body — never '
        'addTearDown', () async {
      final content = await render(widget(), adaptiveSlots: const ['macos']);
      expect(content, contains('finally {'));
      expect(content, contains('_releaseSkinSlot(tester);'));
      expect(
        content,
        contains('debugDefaultTargetPlatformOverride = null;'),
        reason:
            'the release must clear the foundation debug variable — the '
            'framework verifies it at the end of the test body, BEFORE '
            'addTearDown callbacks run (issue #1920)',
      );
      expect(
        content,
        isNot(contains('addTearDown(() => debugDefaultTargetPlatformOverride')),
        reason:
            'addTearDown is the trap the issue documents: it runs too late '
            'and trips the foundation invariant',
      );
      final event = content.indexOf('skin-event: behavior=W1');
      final release = content.indexOf('_releaseSkinSlot(tester);');
      expect(
        release,
        greaterThan(event),
        reason: 'the pin is released after the slot work completes',
      );
    });

    test('the harness pins platform slots and width-defined slots', () async {
      final content = await render(
        widget(),
        adaptiveSlots: const ['mobile', 'ios', 'android', 'macos'],
      );
      // Platform slots pin the platform override.
      expect(content, contains('TargetPlatform.iOS'));
      expect(content, contains('TargetPlatform.android'));
      expect(content, contains('TargetPlatform.macOS'));
      // Width-defined slots pin the surface the adaptive view resolves
      // BEFORE the platform switch.
      expect(content, contains("'mobile' => const Size("));
      expect(content, contains('tester.view.physicalSize'));
      expect(content, contains('tester.view.resetPhysicalSize();'));
    });

    test('the view-builder call stays inside the loop — run-skin discovers '
        'the target by `subject.<name>(`', () async {
      final content = await render(widget(), adaptiveSlots: const ['macos']);
      final loop = content.indexOf('for (final slot in');
      final call = content.indexOf('subject.loginView()');
      expect(loop, greaterThanOrEqualTo(0));
      expect(
        call,
        greaterThan(loop),
        reason:
            'run-skin extracts the view-builder target from the immutable '
            'test source; the slot loop must wrap the real call',
      );
    });

    test(
      'no slots declared keeps the legacy template byte-identical',
      () async {
        final legacy = await render(widget());
        expect(legacy, isNot(contains('platform:flutter/foundation.dart')));
        expect(legacy, isNot(contains('skin-event:')));
        expect(legacy, isNot(contains('_pinSkinSlot')));
        expect(legacy, contains("import 'package:flutter/material.dart';"));
      },
    );

    test('non-widget kinds ignore adaptive slots', () async {
      final unit = Behavior(
        id: 'U1',
        feature: '1920-skin-slots',
        kind: BehaviorKind.unit,
        description: 'returns 42',
        sourceCriterion: 'FR-001',
        target: 'sampleSubject',
      );
      final content = await render(
        unit,
        adaptiveSlots: const ['mobile', 'macos'],
      );
      expect(content, isNot(contains('skin-event:')));
      expect(content, isNot(contains('platform:flutter/foundation.dart')));
    });
  });
}
