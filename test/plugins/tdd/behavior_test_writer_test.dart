/// Tests for `BehaviorTestWriter` — the widget-lane test template contract.
///
/// Inert-stub red context (issue #959 / spec 071-inert-stub-red): with the
/// inert stub as the red surface, the generated widget test's red/green
/// mechanics must hold:
///
///   1. the capture guard (`isNot(isA<UnimplementedError>())`) stays — as
///      the SECONDARY guard for subjects that still throw (FR-005);
///   2. the authored finder assertions run AFTER the pump (FR-002) — they
///      are the PRIMARY red surface against the inert stub;
///   3. the template's comments describe exactly that split (guard =
///      secondary, finders = primary).
///
/// All assertions are CONTENT-level (no Flutter execution): the emitted
/// pair is validated through `write()` into a temp tree (bug_830
/// convention — widget pairs run on the target project's flutter tier).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/red_classification.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/red_classifier.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_scaffold.dart';

void main() {
  Future<String> renderWidgetTest({
    String description = "renders the 'Home' label after sign-in.",
    bool golden = false,
  }) async {
    final dir = Directory.systemTemp.createTempSync('behavior_writer_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final testPath = p.join(dir.path, 'test', 'tdd', 'a1_test.dart');
    final subjectPath = p.join(dir.path, 'lib', 'tdd', 'a1_subject.dart');
    await const BehaviorTestWriter().write(
      behavior: Behavior(
        id: 'A1',
        feature: '071-inert-stub-red',
        kind: BehaviorKind.widget,
        description: description,
        sourceCriterion: 'AC-1',
        target: 'subject_home',
      ),
      testPath: testPath,
      subjectPath: subjectPath,
      golden: golden,
    );
    return File(testPath).readAsString();
  }

  group('behavior test writer: inert-stub red mechanics (issue #959)', () {
    test(
      'the capture guard stays in the emitted test (secondary guard)',
      () async {
        final content = await renderWidgetTest();
        expect(content, contains('on UnimplementedError catch'));
        expect(content, contains('isNot(isA<UnimplementedError>())'));
      },
    );

    test('authored finders run after the pump, the guard before it', () async {
      final content = await renderWidgetTest();
      final guard = content.indexOf('isNot(isA<UnimplementedError>())');
      final pump = content.indexOf('pumpAndSettle()');
      final finder = content.indexOf("find.text('Home')");
      final tail = content.indexOf('find.byWidget(view)');
      expect(guard, greaterThanOrEqualTo(0));
      expect(
        pump,
        greaterThan(guard),
        reason: 'the pump must follow the guard',
      );
      expect(
        finder,
        greaterThan(pump),
        reason:
            'authored finders must execute after the pump: against the inert '
            'stub they are the assertions that fail (the red surface)',
      );
      expect(tail, greaterThan(finder));
    });

    test(
      'a finder-less description still emits the scaffolded marker block',
      () async {
        final content = await renderWidgetTest(
          description: 'renders the dashboard view.',
        );
        expect(
          contentIsScaffolded(content),
          isTrue,
          reason:
              'the marker stays emitted; the mechanical refusal comes '
              'from the unexpected-green verdict against the inert stub',
        );
        expect(content, contains('find.byWidget(view)'));
      },
    );

    test('the golden hook stays available for widget pairs', () async {
      final content = await renderWidgetTest(golden: true);
      expect(content, contains('matchesGoldenFile('));
    });

    test(
      'comments name the guard secondary and the finders the primary red',
      () async {
        final content = await renderWidgetTest();
        expect(
          content.toLowerCase(),
          contains('secondary'),
          reason:
              'the guard is the secondary red surface (issue #959 '
              'acceptance 3); the template must say so',
        );
        expect(
          content.toLowerCase(),
          contains('primary'),
          reason:
              'the authored finders are the primary red surface against '
              'the inert stub; the template must say so',
        );
      },
    );

    test('renders are deterministic — only the subject file separates red '
        'from green (zero assertion edits, A2/U6)', () async {
      final first = await renderWidgetTest();
      final second = await renderWidgetTest();
      expect(
        second,
        first,
        reason:
            'the emitted test must be identical across renders: the red→green '
            'transition swaps ONLY the subject stub body — authored assertions '
            'are never edited',
      );
    });

    test('a vacuous-only template against the inert stub is green at red '
        'time — unexpected-green refusal (U4/U8/A4/A5)', () async {
      // The scaffolded template (finder-less description) carries ONLY the
      // vacuous tail finder: find.byWidget(view) passes against ANY widget,
      // including the inert stub's SizedBox.shrink. At red time every
      // assertion therefore PASSES — the transcript is green — and the
      // classifier's verdict is unexpected-green: the mechanical refusal
      // that replaces the honor-system marker check.
      final content = await renderWidgetTest(
        description: 'renders the dashboard view.',
      );
      expect(contentIsScaffolded(content), isTrue);
      expect(content, contains('find.byWidget(view)'));
      expect(
        content,
        isNot(contains('find.text(')),
        reason: 'vacuous-only: no content-inspecting finder exists',
      );
      const greenAtRedTime = '''
00:00 +0: loading test/b_001_test.dart
00:00 +1: B-001 — renders the dashboard view
00:00 +1: All tests passed!
''';
      final verdict = classify(
        RunRecord(
          command: 'flutter test test/b_001_test.dart --plain-name "B-001"',
          exitCode: 0,
          output: greenAtRedTime,
          startedProcess: true,
          testCount: 1,
        ),
      );
      expect(
        verdict,
        RedClassification.unexpectedGreen,
        reason:
            'a scaffolded test cannot certify red: it is already green against '
            'the inert stub, and verify-red refuses unexpected-green',
      );
    });
  });
}
