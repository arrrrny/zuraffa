// SPEC 1685 — review bot snippet template must be compilable
// (issue #1685: zuraffa-review[bot] proposed addTearDown(_tmp.deleteRecursively)
// on arrrrny/zuraffa_browser#165 — undefined_getter; the fix pins the
// deleteSync(recursive: true) shape and adds the snippet validation gate so
// un-compilable suggestions are never posted).
//
// Test map:
//   U-1685-G1 (SC-1) — catalog shape: the temp-dir-cleanup template renders
//     the deleteSync(recursive: true) shape; NO template references a
//     deny-listed (verified non-existent) API member.
//   U-1685-G2 (SC-2) — the validation gate rejects the HISTORICAL buggy
//     snippet verbatim (static scan + REAL analyzer compile check) and
//     passes the fixed render with zero analyzer errors.
//   U-1685-G3 — the posting gate: postableSnippet returns compiled-verified
//     code; unknown template ids are rejected.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/review_snippets.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/snippet_compile_check.dart';

void main() {
  group('SPEC 1685 — review bot snippet compilable', () {
    // ---------------------------------------------------------------
    // U-1685-G1 — the catalog shape (SC-1)
    // ---------------------------------------------------------------
    test('U-1685-G1: tempDirCleanup renders the deleteSync(recursive: true) '
        'shape from the issue workaround', () {
      final code = ReviewSnippets.render(ReviewSnippets.tempDirCleanupId);
      expect(code, contains('Directory.systemTemp.createTempSync'));
      expect(code, contains('addTearDown'));
      // The EXACT workaround shape from issue #1685 — plain dart:io.
      expect(code, contains('deleteSync(recursive: true)'));
      // The non-existent API must not appear in ANY form.
      expect(code.contains('deleteRecursively'), isFalse);
    });

    test('U-1685-G1: no template in the catalog references any deny-listed '
        '(verified non-existent) API member', () {
      expect(ReviewSnippets.all, isNotEmpty);
      for (final template in ReviewSnippets.all) {
        final found = SnippetDenyList.scan(template.code);
        expect(
          found,
          isEmpty,
          reason:
              'template ${template.id} references a non-existent API: '
              '${found.map((i) => i.message).join("; ")}',
        );
      }
    });

    // ---------------------------------------------------------------
    // U-1685-G2 — the historical buggy snippet is rejected (SC-2)
    // ---------------------------------------------------------------
    test('U-1685-G2: static scan rejects the historical snippet verbatim '
        '(addTearDown(_tmp.deleteRecursively))', () {
      // VERBATIM as posted on arrrrny/zuraffa_browser#165, inline
      // comment id 4023967373.
      const buggy = 'addTearDown(_tmp.deleteRecursively)';
      final issues = SnippetDenyList.scan(buggy);
      expect(issues, hasLength(1));
      expect(issues.single.code, 'non_existent_api');
      expect(issues.single.message, contains('deleteRecursively'));
      expect(issues.single.message, contains('deleteSync({recursive: true})'));
    });

    test('U-1685-G2: REAL analyzer compile check rejects the historical '
        'snippet (undefined_getter, the issue\'s exact error)', () async {
      const buggy =
          "final _tmp = Directory.systemTemp.createTempSync('x_');\n"
          'addTearDown(_tmp.deleteRecursively);';
      final result = await const SnippetCompileCheck().compileCheck(buggy);
      expect(
        result.passed,
        isFalse,
        reason: 'the historical snippet must NOT compile',
      );
      expect(result.issues.map((i) => i.code), contains('undefined_getter'));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('U-1685-G2: the fixed render passes the REAL analyzer compile check '
        'with zero errors', () async {
      final code = ReviewSnippets.render(ReviewSnippets.tempDirCleanupId);
      final result = await const SnippetCompileCheck().compileCheck(code);
      expect(
        result.passed,
        isTrue,
        reason:
            'fixed snippet must compile — '
            '${result.issues.map((i) => "[${i.code}] ${i.message}").join("\n")}',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('U-1685-G2: validate() combines both layers — scan error short-'
        'circuits before the analyzer', () async {
      const buggy = 'addTearDown(_tmp.deleteRecursively)';
      final result = await const SnippetCompileCheck().validate(buggy);
      expect(result.passed, isFalse);
      expect(result.issues.map((i) => i.code), contains('non_existent_api'));
    });

    // ---------------------------------------------------------------
    // U-1685-G3 — the posting gate
    // ---------------------------------------------------------------
    test('U-1685-G3: postableSnippet returns compiled-verified code', () async {
      final code = await ReviewSnippets.postableSnippet(
        ReviewSnippets.tempDirCleanupId,
      );
      expect(code, contains('deleteSync(recursive: true)'));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('U-1685-G3: unknown template id throws ArgumentError', () {
      expect(
        () => ReviewSnippets.render('no_such_template'),
        throwsArgumentError,
      );
      expect(
        () => ReviewSnippets.postableSnippet('no_such_template'),
        throwsArgumentError,
      );
    });
  });
}
