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

  // Keep the import used: SnippetValidationIssue is the finding type the
  // guard reports (shared with the spec-1685 gate vocabulary).
  test('guard findings use the shared validation-issue vocabulary', () {
    final issues = SuggestionDiffGuard.scanBody('$_raptorr504Diff\n');
    expect(issues, everyElement(isA<SnippetValidationIssue>()));
  });
}
