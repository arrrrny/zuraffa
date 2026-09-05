// Issue #1005 ([ZIKZAK-REBUILD] skin hand-written seam): the
// `_XRaySkinHandEdit` annotation scanner — the source-level, cycle-verified
// hand-edit marker the skin receipt captures.
//
// RED phase: `skin_hand_edit.dart` does not exist — every import fails.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/skin_hand_edit.dart';

void main() {
  group('issue #1005 — _XRaySkinHandEdit scanning', () {
    test('scans a single-line annotation', () {
      const source = '''
/// LoginView — the first hand-written skin.
// _XRaySkinHandEdit(behavior: "W1", file: "lib/src/presentation/pages/login/login_view.dart", logged_at: "2026-09-05T00:00:00Z")
Widget loginView() => const LoginView();
''';
      final edits = scanSkinHandEdits(source);
      expect(edits, hasLength(1));
      expect(edits.first.behavior, 'W1');
      expect(
        edits.first.file,
        'lib/src/presentation/pages/login/login_view.dart',
      );
      expect(edits.first.loggedAt, '2026-09-05T00:00:00Z');
    });

    test('scans a doc-comment annotation wrapped across lines', () {
      const source = '''
/// _XRaySkinHandEdit(behavior: "W1",
///   file: "lib/src/presentation/pages/login/login_view.dart",
///   logged_at: "2026-09-05T00:00:00Z")
library;
''';
      final edits = scanSkinHandEdits(source);
      expect(edits, hasLength(1));
      expect(edits.first.behavior, 'W1');
      expect(edits.first.loggedAt, '2026-09-05T00:00:00Z');
    });

    test('scans multiple annotations across a file', () {
      const source = '''
// _XRaySkinHandEdit(behavior: "W1", file: "lib/a.dart", logged_at: "2026-09-05T00:00:00Z")
// _XRaySkinHandEdit(behavior: "W2", file: "lib/b.dart", logged_at: "2026-09-05T01:00:00Z")
''';
      final edits = scanSkinHandEdits(source);
      expect(edits.map((e) => e.behavior), ['W1', 'W2']);
    });

    test('a malformed annotation (missing logged_at) is not scanned', () {
      const source = '''
// _XRaySkinHandEdit(behavior: "W1", file: "lib/a.dart")
''';
      expect(scanSkinHandEdits(source), isEmpty);
    });

    test('a partial token that merely contains the name is not scanned', () {
      const source = '''
// _XRaySkinHandEdit(behavior: "W1", file: "lib/a.dart", logged_at: "not-a-date")
''';
      final edits = scanSkinHandEdits(source);
      // The shape matches; the ISO-8601 validation is the conformance
      // check, not the scanner's job — the scanner reports it verbatim.
      expect(edits, hasLength(1));
      expect(edits.first.loggedAt, 'not-a-date');
    });
  });

  group('issue #1005 — annotation cross-checks (conformance)', () {
    const edit = SkinHandEdit(
      behavior: 'W1',
      file: 'lib/src/presentation/pages/login/login_view.dart',
      loggedAt: '2026-09-05T00:00:00Z',
    );

    test('matches its behavior row and project-relative subject path', () {
      expect(
        edit.matches(
          behaviorId: 'W1',
          subjectRelPath: 'lib/src/presentation/pages/login/login_view.dart',
        ),
        isTrue,
      );
    });

    test('refuses a different behavior id', () {
      expect(
        edit.matches(
          behaviorId: 'W2',
          subjectRelPath: 'lib/src/presentation/pages/login/login_view.dart',
        ),
        isFalse,
      );
    });

    test('refuses a different file path', () {
      expect(
        edit.matches(behaviorId: 'W1', subjectRelPath: 'lib/other.dart'),
        isFalse,
      );
    });

    test('loggedAt validation: a parseable ISO-8601 stamp is valid', () {
      expect(edit.hasValidTimestamp, isTrue);
    });

    test('loggedAt validation: garbage is invalid', () {
      const bad = SkinHandEdit(
        behavior: 'W1',
        file: 'lib/a.dart',
        loggedAt: 'not-a-date',
      );
      expect(bad.hasValidTimestamp, isFalse);
    });
  });
}
