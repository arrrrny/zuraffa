// Bug #912 defect 1 — literal safety: behavior descriptions are injected
// into single-quoted Dart string literals by every gen template. A
// description carrying an apostrophe, quote, backslash, `$`/`${}`
// interpolation, or control character must be ESCAPED first, or the
// generated test is an unterminated / mis-interpolated literal that never
// compiles (the defect register's "persist the user's theme preference"
// repro).
//
// The pin: render EVERY template (default, persistence, widget, ffi) with
// one hostile description and parse the result with the analyzer — zero
// syntax errors — plus the `$` must be escaped (`\$`), never left as a raw
// interpolation inside the emitted string literals.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';

/// Hostile on every axis the defect register names: apostrophe, double
/// quotes, backslash, `${}` interpolation, unicode. Raw string so the
/// test source itself stays readable.
const String hostileDescription =
    r"""persist the user's theme 'quoted' "dq" back\slash ${interp} preference""";

Behavior behaviorOf(BehaviorKind kind, {bool persistence = false}) => Behavior(
  id: 'B-912',
  feature: '912-template-self-hosting',
  kind: kind,
  description: hostileDescription,
  sourceCriterion: 'FR-912',
  target: 'subjectUnderTest',
  persistence: persistence,
);

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug912_literal_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  /// Renders a template through [write] and returns the emitted source.
  Future<String> render(Behavior behavior) async {
    final testPath = p.join(tmpDir.path, 'b_912_test.dart');
    final subjectPath = p.join(tmpDir.path, 'b_912_subject.dart');
    await const BehaviorTestWriter().write(
      behavior: behavior,
      testPath: testPath,
      subjectPath: subjectPath,
    );
    return File(testPath).readAsString();
  }

  List<Diagnostic> syntaxErrorsOf(String source) => parseString(
    content: source,
    throwIfDiagnostics: false,
  ).errors.cast<Diagnostic>();

  group('bug 912 defect 1: literal-safety pins (one per template)', () {
    test('default (plain-function) template', () async {
      final content = await render(behaviorOf(BehaviorKind.acceptance));
      final errors = syntaxErrorsOf(content);
      expect(
        errors,
        isEmpty,
        reason:
            'the default template must escape the behavior description '
            'before injecting it into a Dart string literal; got: '
            '${errors.map((e) => '${e.offset}: ${e.message}').join(', ')}',
      );
      // The `$` of `${interp}` must be escaped in the emitted literal —
      // a raw `$` would interpolate an undefined identifier at runtime.
      expect(content, contains(r'\${interp}'));
    });

    test('persistence template (the defect register repro)', () async {
      final content = await render(
        behaviorOf(BehaviorKind.unit, persistence: true),
      );
      final errors = syntaxErrorsOf(content);
      expect(
        errors,
        isEmpty,
        reason:
            "the persistence template emitted 'persist the user's theme' "
            'UNESCAPED — an unterminated string literal (issue #912 '
            'defect 1); got: '
            '${errors.map((e) => '${e.offset}: ${e.message}').join(', ')}',
      );
      expect(content, contains(r'\${interp}'));
    });

    test('widget template', () async {
      final content = await render(behaviorOf(BehaviorKind.widget));
      final errors = syntaxErrorsOf(content);
      expect(
        errors,
        isEmpty,
        reason:
            'the widget template must escape the behavior description; '
            'got: ${errors.map((e) => '${e.offset}: ${e.message}').join(', ')}',
      );
      expect(content, contains(r'\${interp}'));
    });

    test('ffi (binding contract) template', () async {
      final b = behaviorOf(BehaviorKind.ffi);
      final content = const BehaviorTestWriter().renderContractTest(
        b,
        p.join(tmpDir.path, 'b_912_test.dart'),
        p.join(tmpDir.path, 'b_912_subject.dart'),
      );
      final errors = syntaxErrorsOf(content);
      expect(
        errors,
        isEmpty,
        reason:
            'the ffi contract template must escape the behavior '
            'description; got: '
            '${errors.map((e) => '${e.offset}: ${e.message}').join(', ')}',
      );
      expect(content, contains(r'\${interp}'));
    });

    test('escapeDartString covers the defect register axis set', () {
      const raw = "a'b\"c\\d\$e\${f}g\nh\ti";
      final escaped = BehaviorTestWriter.escapeDartString(raw);
      // Round-trip: the escaped form must sit inside a single-quoted
      // literal with zero syntax errors.
      final errors = syntaxErrorsOf("var s = '$escaped';");
      expect(errors, isEmpty, reason: 'escaped: $escaped');
      expect(escaped, contains(r"\'"));
      // Issue #1035: every interpolation site is a single-quoted literal,
      // so a double quote needs NO escape — emitting `\"` would trip
      // unnecessary_string_escapes in the generated artifact.
      expect(escaped, contains('"'));
      expect(escaped, isNot(contains(r'\"')));
      expect(escaped, contains(r'\\'));
      expect(escaped, contains(r'\$'));
      expect(escaped, contains(r'\n'));
      expect(escaped, contains(r'\t'));
    });
  });
}
