/// Tests for `SubjectWriter` — the stub half of a `zfa tdd gen` pair.
///
/// Inert-stub red contract (issue #959 / spec 071-inert-stub-red, FR-001):
/// the widget-kind subject is the RED SURFACE of the widget lane. It must
/// be INERT but VALID — a renderable widget that displays nothing — so the
/// generated widget test's guard assertion passes, the pump runs, and the
/// AUTHORED FINDER assertions are what fail at red time. A throwing stub
/// aborts the test at the guard (`isNot(isA<UnimplementedError>())`),
/// leaving the authored finders never-executed ("born green") — the defect
/// this contract removes.
///
/// All assertions are CONTENT-level (no Flutter execution): widget pairs
/// run on the target project's flutter tier; this suite validates the
/// emitted source (same convention as bug_830_widget_subject_kind_test).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';

void main() {
  final behavior = Behavior(
    id: 'A1',
    feature: '071-inert-stub-red',
    kind: BehaviorKind.widget,
    description: "the dashboard renders the 'Home' label after sign-in.",
    sourceCriterion: 'AC-1',
    target: 'subject_home',
  );

  group('subject writer: widget kind is the inert red surface (issue #959)', () {
    test('the view-builder stub body is an inert, valid widget', () {
      final content = const SubjectWriter().render(behavior);
      expect(
        content,
        contains('Widget subject_home() => const SizedBox.shrink();'),
        reason:
            'the widget-lane red surface must be an inert-but-valid widget: '
            'the guard passes, the pump runs, and authored finders fail',
      );
    });

    test('the stub body never throws UnimplementedError', () {
      final content = const SubjectWriter().render(behavior);
      final bodyStart = content.indexOf('Widget subject_home()');
      expect(bodyStart, greaterThanOrEqualTo(0));
      final body = content.substring(bodyStart);
      expect(
        body,
        isNot(contains('UnimplementedError')),
        reason:
            'a throwing stub certifies red at the guard and aborts the '
            'test before the authored finders execute (born-green defect)',
      );
    });

    test('the stub compiles with only the material import', () {
      final content = const SubjectWriter().render(behavior);
      expect(content, contains("import 'package:flutter/material.dart';"));
      expect(content, isNot(contains('shadcn_ui')));
    });

    test('the stub header keeps behavior traceability', () {
      final content = const SubjectWriter().render(behavior);
      expect(content, contains('behavior_id: A1'));
      expect(content, contains('source_criterion: AC-1'));
    });

    test('the stub doc comment names the inert red surface and the remedy', () {
      final content = const SubjectWriter().render(behavior);
      expect(
        content.toLowerCase(),
        contains('inert'),
        reason:
            'the doc comment must tell the implementer this body is the '
            'deliberate red surface to be replaced by the real view builder',
      );
      expect(content.toLowerCase(), contains('replace'));
    });
  });
}
