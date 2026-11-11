// SPEC 2064 — review-bot suggestion must not break block comments
// (issue #2064: zuraffa-review[bot]'s inline suggestion on arrrrny/raptorr#504,
// review comment 4532260043, proposed a docblock reword whose added lines
// contain the `**/*.spec.ts` glob — the `*/` inside `**/` closed the block
// comment at apply time and the file no longer compiled).
//
// Test map:
//   U-2064-G1 — the HISTORICAL misfire body (raptorr#504, verbatim diff
//     block) is flagged: the removed lines are docblock interior, so the
//     target lies inside a block comment and the added line containing
//     `**/*.spec.ts` carries the terminator sequence.
//   U-2064-G2 — no false positives: a `*/` in added lines whose target is
//     NOT a block comment (removed lines are plain code) is not flagged,
//     and a docblock-suggestion whose added lines contain no `*/` passes.
//   U-2064-G3 — a suggestion that legitimately ADDS a block-comment closer
//     (removed lines are code, not comment interior) is not flagged.
//   U-2064-G4 — the posting path: the verbatim misfire body is refused
//     before any request is sent; a reworded safe body posts.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/pr_comment_poster.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/snippet_compile_check.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/suggestion_diff_guard.dart';

class RecordingClient extends http.BaseClient {
  final List<http.Request> sent = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request as http.Request);
    return http.StreamedResponse(Stream.value(utf8.encode('{"id": 1}')), 201);
  }

  @override
  void close() {}
}

/// The ```diff block of arrrrny/raptorr#504 review comment 4532260043,
/// verbatim (the suggested docblock reword).
const _raptorr504Diff =
    '```diff\n'
    '- * bun-only by design (`bun:test`): a filesystem-static guard with no runtime\n'
    '- * module graph — `src/tests/` keeps it out of the vitest glob.\n'
    '+ * bun-only by design (`bun:test`): a filesystem-static guard with no runtime\n'
    '+ * module graph — the `.test.ts` extension keeps it out of both vitest\n'
    '+ * configs, which include only `**/*.spec.ts` / `**/*.spec.tsx`.\n'
    '```';

void main() {
  group('SPEC 2064 — suggestion diff guard', () {
    test('U-2064-G1: the historical raptorr#504 misfire body is flagged '
        '(added lines carry `*/` inside a block-comment target)', () {
      final issues = SuggestionDiffGuard.scanBody(
        'Comment-accuracy nit. Suggested reword:\n\n$_raptorr504Diff\n',
      );

      expect(issues, isNotEmpty);
      expect(
        issues.any((i) => i.code == 'comment_terminator_in_suggestion'),
        isTrue,
        reason:
            'the `**/*.spec.ts` added line must be flagged — its `*/` '
            'terminates the enclosing block comment when applied verbatim',
      );
    });

    test('U-2064-G1: the flag names the offending line and the fix', () {
      final issues = SuggestionDiffGuard.scanBody('$_raptorr504Diff\n');

      final issue = issues.singleWhere(
        (i) => i.code == 'comment_terminator_in_suggestion',
      );
      expect(issue.message, contains('`*/`'));
      expect(issue.message, contains('**/*.spec.ts'));
    });

    test('U-2064-G2: no false positive — `*/` in added lines whose target '
        'is NOT a block comment is not flagged', () {
      // The removed line is plain code, so the hunk does not rewrite a
      // comment interior; the glob is safe there.
      const body =
          '```diff\n'
          '- const include = [];\n'
          '+ const include = ["**/*.spec.ts"];\n'
          '```\n';

      expect(SuggestionDiffGuard.scanBody(body), isEmpty);
    });

    test('U-2064-G2: a docblock reword whose added lines contain no `*/` '
        'passes', () {
      const body =
          '```diff\n'
          '- * module graph — `src/tests/` keeps it out of the vitest glob.\n'
          '+ * module graph — the `.test.ts` extension keeps it out of the\n'
          '+ * vitest configs entirely.\n'
          '```\n';

      expect(SuggestionDiffGuard.scanBody(body), isEmpty);
    });

    test('U-2064-G3: a suggestion that ADDS a block-comment closer over '
        'code lines is not flagged', () {
      const body =
          '```diff\n'
          '- const x = 1;\n'
          '+ /** docs */\n'
          '+ const x = 1;\n'
          '```\n';

      expect(SuggestionDiffGuard.scanBody(body), isEmpty);
    });

    test('U-2064-G4: the posting path refuses the verbatim misfire body '
        'before any request is sent', () async {
      final client = RecordingClient();
      final poster = GithubPrCommentPoster(
        repoSlug: 'arrrrny/raptorr',
        prNumber: 504,
        token: 'gh-token',
        client: client,
      );

      final ok = await poster.postComment(
        'Comment-accuracy nit. Suggested reword:\n\n$_raptorr504Diff\n',
      );

      expect(
        ok,
        isFalse,
        reason: 'the comment-terminator suggestion must NOT post',
      );
      expect(client.sent, isEmpty);
    });

    test('U-2064-G4: a reworded safe suggestion posts', () async {
      final client = RecordingClient();
      final poster = GithubPrCommentPoster(
        repoSlug: 'arrrrny/raptorr',
        prNumber: 504,
        token: 'gh-token',
        client: client,
      );

      final ok = await poster.postComment(
        'Suggested reword:\n\n'
        '```diff\n'
        '- * module graph — `src/tests/` keeps it out of the vitest glob.\n'
        '+ * module graph — the `.test.ts` extension keeps it out of the\n'
        '+ * vitest configs entirely.\n'
        '```\n',
      );

      expect(ok, isTrue);
      expect(client.sent, hasLength(1));
    });

    test('a body with no diff fence never touches the guard', () {
      expect(
        SuggestionDiffGuard.scanBody('plain prose, no suggestion\n'),
        isEmpty,
      );
    });
  });

  // PR #2065 review round: the refinements the reviewer findings asked
  // for — own-line fence extraction, per-hunk classification,
  // context-derived comment state, and the closer carve-outs.
  group('PR #2065 review round — guard refinements', () {
    test('an inline ``` inside a diff line cannot terminate extraction — '
        'the added line after it is still scanned', () {
      // The old fence regex stopped at the first three backticks: the
      // removed `Example: ```js` line ended the block and the unsafe
      // added line escaped validation entirely.
      const body =
          '```diff\n'
          '- * Example: ```js\n'
          '- * old text\n'
          '+ * new text mentioning **/*.spec.ts\n'
          '```\n';

      expect(
        SuggestionDiffGuard.scanBody(
          body,
        ).any((i) => i.code == 'comment_terminator_in_suggestion'),
        isTrue,
        reason:
            'the closing fence must be a line of its own — the inline '
            '```js marker is diff content, not a fence',
      );
    });

    test('an unterminated diff fence still matches nothing', () {
      expect(
        SuggestionDiffGuard.scanBody('```diff\n- * text, never closed\n'),
        isEmpty,
      );
    });

    test('per-hunk classification: a docblock hunk is flagged even when '
        'another hunk in the same block removes plain code', () {
      // Aggregating removals across the whole block (the pre-#2065 shape)
      // let the code hunk's `const` line cancel the docblock hunk's
      // interior signal and the unsafe addition passed.
      const body =
          '```diff\n'
          '@@ -10,3 +10,3 @@\n'
          '- * old doc text\n'
          '+ * new doc text mentioning **/*.spec.ts\n'
          '@@ -40,2 +40,2 @@\n'
          '- const include = [];\n'
          '+ const include = ["**/*.spec.ts"];\n'
          '```\n';

      final issues = SuggestionDiffGuard.scanBody(body);
      expect(
        issues.any((i) => i.code == 'comment_terminator_in_suggestion'),
        isTrue,
        reason: 'the docblock hunk must be classified on its own',
      );
      // ...and only the docblock hunk's line is flagged.
      expect(issues, hasLength(1));
    });

    test('context-derived state: a hunk whose removed lines are bare '
        'docblock text (no `*` marker) is flagged when unchanged context '
        'opens the comment', () {
      const body =
          '```diff\n'
          ' /*\n'
          '- old description\n'
          '+ Match **/*.spec.ts\n'
          ' */\n'
          '```\n';

      expect(
        SuggestionDiffGuard.scanBody(
          body,
        ).any((i) => i.code == 'comment_terminator_in_suggestion'),
        isTrue,
        reason:
            'the comment opened on an unchanged line must participate — '
            'removed docblock text needs no `*` continuation marker',
      );
    });

    test('opener-inclusive hunk: rewriting the docblock `/**` first line '
        'with a `*/` in the new text is flagged', () {
      const body =
          '```diff\n'
          '- /** Parses config files.\n'
          '+ /** Parses **/*.spec.ts configs.\n'
          ' */\n'
          '```\n';

      expect(
        SuggestionDiffGuard.scanBody(
          body,
        ).any((i) => i.code == 'comment_terminator_in_suggestion'),
        isTrue,
        reason:
            'a `/*`-prefixed removed line is comment interior too — the '
            'glob in the rewritten opener would close the comment early',
      );
    });

    test('single-line docblock reword carrying `*/` mid-line is flagged', () {
      const body =
          '```diff\n'
          '- /** old */\n'
          '+ /** matches **/*.spec.ts */\n'
          '```\n';

      expect(
        SuggestionDiffGuard.scanBody(
          body,
        ).any((i) => i.code == 'comment_terminator_in_suggestion'),
        isTrue,
        reason:
            'the first `*/` inside `**/` closes the reworded docblock '
            'early and the rest of the line becomes live code',
      );
    });

    test('widened interior rule keeps a code target unflagged: a docblock '
        'line replaced by plain code with a glob passes', () {
      // The `/*` arm of _isCommentInteriorLine must not make a comment
      // line replaced BY code a comment target: the glob sits in a string
      // literal of a code line, not in comment text.
      const body =
          '```diff\n'
          '- /** Parses config files. */\n'
          '+ const include = ["**/*.spec.ts"];\n'
          '```\n';

      expect(SuggestionDiffGuard.scanBody(body), isEmpty);
    });

    test('closer-preserving replacement: a reword that ends with the '
        'comment closer is allowed', () {
      const body =
          '```diff\n'
          '- * Old description\n'
          '- */\n'
          '+ * New description */\n'
          '```\n';

      expect(
        SuggestionDiffGuard.scanBody(body),
        isEmpty,
        reason:
            'the replacement keeps the comment boundary — nothing after '
            'the closing `*/` is exposed',
      );
    });

    test('pure closer insertion: an added bare ` */` is not flagged', () {
      const body =
          '```diff\n'
          '+ */\n'
          '```\n';

      expect(
        SuggestionDiffGuard.scanBody(body),
        isEmpty,
        reason:
            'inserting the legitimate docblock closer is exactly the '
            'right edit — it terminates the comment cleanly',
      );
    });
  });

  // PR #2065 second review round: the four findings the reviewer asked
  // for — CRLF fence extraction, full file-header syntax, the additions'
  // original-position scan state, and the retained-context check on a
  // clean enclosing closer.
  group('PR #2065 second review round — guard refinements', () {
    test('a CRLF comment body is scanned: the fence accepts CR line '
        'endings', () {
      const body =
          '```diff\r\n'
          '- * old doc text\r\n'
          '+ * new doc text mentioning **/*.spec.ts\r\n'
          '```\r\n';

      expect(
        SuggestionDiffGuard.scanBody(
          body,
        ).any((i) => i.code == 'comment_terminator_in_suggestion'),
        isTrue,
        reason:
            'a CRLF body must reach the guard — the fence must extract '
            'the block instead of matching nothing and letting the '
            'posting gate publish an unscanned suggestion',
      );
    });

    test('a CRLF safe body still passes', () {
      const body =
          '```diff\r\n'
          '- * old doc text\r\n'
          '+ * new doc text entirely.\r\n'
          '```\r\n';

      expect(SuggestionDiffGuard.scanBody(body), isEmpty);
    });

    test('an added line whose content starts with `++` is scanned, not '
        'dropped as a file header', () {
      // The added content `++**/*.spec.ts` reads as `+++…` in the diff;
      // the prefix check dropped it as a header and the `*/` escaped the
      // scan entirely.
      const body =
          '```diff\n'
          ' /*\n'
          '+++**/*.spec.ts\n'
          ' */\n'
          '```\n';

      expect(
        SuggestionDiffGuard.scanBody(
          body,
        ).any((i) => i.code == 'comment_terminator_in_suggestion'),
        isTrue,
        reason:
            'the `+++`-prefixed ADDED line is not a file header — its '
            'glob must be scanned inside the comment the context opened',
      );
    });

    test('a real file header still splits hunks', () {
      const body =
          '```diff\n'
          'diff --git a/glob.ts b/glob.ts\n'
          '--- a/glob.ts\n'
          '+++ b/glob.ts\n'
          '@@ -10,3 +10,3 @@\n'
          '- * old doc text\n'
          '+ * new doc text mentioning **/*.spec.ts\n'
          '```\n';

      final issues = SuggestionDiffGuard.scanBody(body);
      expect(
        issues.any((i) => i.code == 'comment_terminator_in_suggestion'),
        isTrue,
        reason:
            'the header lines are dropped as boundaries and the hunk is '
            'classified on its own',
      );
      expect(issues, hasLength(1));
    });

    test('a replacement is scanned at its ORIGINAL position: the removed '
        'closer cannot close the target comment before the addition is '
        'scanned', () {
      const body =
          '```diff\n'
          ' /** start\n'
          '- * old */\n'
          '+ * paths **/*.spec.ts */\n'
          '```\n';

      expect(
        SuggestionDiffGuard.scanBody(
          body,
        ).any((i) => i.code == 'comment_terminator_in_suggestion'),
        isTrue,
        reason:
            'the addition replaces ` * old */` INSIDE the comment ` '
            '/** start` opened — the removed closer must not reset the '
            'scan state before the addition is checked',
      );
    });

    test('a clean enclosing closer with retained context after it is '
        'flagged', () {
      const body =
          '```diff\n'
          ' /** start\n'
          '- * old text\n'
          '+ * new text */\n'
          ' * details\n'
          ' */\n'
          '```\n';

      expect(
        SuggestionDiffGuard.scanBody(
          body,
        ).any((i) => i.code == 'comment_terminator_in_suggestion'),
        isTrue,
        reason:
            'the closer ends the comment the context opened — the '
            'retained ` * details` line leaves the comment with it and '
            'becomes live code',
      );
    });

    test('blank retained lines after a clean enclosing closer are '
        'allowed', () {
      const body =
          '```diff\n'
          ' /** start\n'
          '- * old text\n'
          '+ * new text */\n'
          '\n'
          '```\n';

      expect(SuggestionDiffGuard.scanBody(body), isEmpty);
    });

    test('a replacement that also removes the original closer keeps its '
        'retained lines gone — allowed', () {
      const body =
          '```diff\n'
          ' /** start\n'
          '- * old text\n'
          '- * details\n'
          '- */\n'
          '+ * new text */\n'
          '```\n';

      expect(SuggestionDiffGuard.scanBody(body), isEmpty);
    });

    test('a self-contained added docblock followed by code stays '
        'allowed', () {
      const body =
          '```diff\n'
          '- const x = 1;\n'
          '+ /** docs */\n'
          '+ const x = 1;\n'
          '```\n';

      expect(
        SuggestionDiffGuard.scanBody(body),
        isEmpty,
        reason:
            'the closer ends a comment the line opened ITSELF — the '
            'lines after it were never inside a comment',
      );
    });
  });

  // Keep the import used: SnippetValidationIssue is the finding type the
  // guard reports (shared with the spec-1685 gate vocabulary).
  test('guard findings use the shared validation-issue vocabulary', () {
    final issues = SuggestionDiffGuard.scanBody('$_raptorr504Diff\n');
    expect(issues, everyElement(isA<SnippetValidationIssue>()));
  });
}
