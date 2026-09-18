// U12-U13 (spec 070): the PR comment poster — posts the verdict comment
// to a pull request through the GitHub API (US1, SC-001), with a
// dry-run sink that renders locally without any network access.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/pr_comment_poster.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/review_snippets.dart';

class RecordingClient extends http.BaseClient {
  final List<http.Request> sent = [];
  int statusToReturn = 201;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request as http.Request);
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"id": 1}')),
      statusToReturn,
    );
  }

  @override
  void close() {}
}

void main() {
  group('PrCommentPoster (US1, SC-001)', () {
    test('U12: posts the verdict comment body to the PR issue-comment '
        'endpoint with the token header', () async {
      final client = RecordingClient();
      final poster = GithubPrCommentPoster(
        repoSlug: 'arrrrny/zuraffa',
        prNumber: 42,
        token: 'gh-token',
        client: client,
      );

      final ok = await poster.postComment('## CI Referee Verdict');

      expect(ok, isTrue);
      expect(client.sent, hasLength(1));
      final request = client.sent.single;
      expect(
        request.url.toString(),
        'https://api.github.com/repos/arrrrny/zuraffa/issues/42/comments',
      );
      expect(request.headers['Authorization'], 'Bearer gh-token');
      expect(request.headers['Accept'], 'application/vnd.github+json');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['body'], '## CI Referee Verdict');
    });

    test('U12: an API failure is reported as not-posted, never crashes the '
        'referee', () async {
      final client = RecordingClient()..statusToReturn = 500;
      final poster = GithubPrCommentPoster(
        repoSlug: 'arrrrny/zuraffa',
        prNumber: 42,
        token: 'gh-token',
        client: client,
      );

      final ok = await poster.postComment('## CI Referee Verdict');
      expect(ok, isFalse);
    });

    test('U13: dry-run renders the comment locally with zero network '
        'access', () async {
      final poster = DryRunPrCommentPoster();
      final ok = await poster.postComment('## CI Referee Verdict\nbody');

      expect(ok, isTrue);
      expect(poster.rendered, isNotNull);
      expect(poster.rendered, contains('## CI Referee Verdict'));
    });
  });

  // PR #1703 review fix: the spec-1685 snippet gate is load-bearing —
  // nothing leaves through this transport without compiling.
  group('SnippetPostingGate (PR #1703 review fix)', () {
    test('gate extraction: dartBlocks finds fenced dart blocks only', () {
      const gate = SnippetPostingGate();
      const body = 'prose\n\n```dart\nfoo();\n```\n\n```json\n{"x":1}\n```\n';
      expect(gate.dartBlocks(body), ['foo();']);
    });

    test('a body whose dart block is the HISTORICAL misfire snippet is '
        'blocked before any request is sent', () async {
      final client = RecordingClient();
      final poster = GithubPrCommentPoster(
        repoSlug: 'arrrrny/zuraffa',
        prNumber: 42,
        token: 'gh-token',
        client: client,
      );

      final ok = await poster.postComment(
        'Suggestion:\n\n```dart\naddTearDown(_tmp.deleteRecursively);\n```\n',
      );

      expect(ok, isFalse, reason: 'the un-compilable snippet must NOT post');
      expect(client.sent, isEmpty);
    });

    test('a body with a compilable dart block posts', () async {
      final client = RecordingClient();
      final poster = GithubPrCommentPoster(
        repoSlug: 'arrrrny/zuraffa',
        prNumber: 42,
        token: 'gh-token',
        client: client,
      );

      final ok = await poster.postComment(
        'Suggestion:\n\n```dart\n'
        "final dir = Directory.systemTemp.createTempSync('x_');\n"
        '```\n',
      );

      expect(ok, isTrue, reason: 'a compilable snippet posts');
      expect(client.sent, hasLength(1));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('postSnippetSuggestion assembles from the validated catalog '
        '(postableSnippet — the sanctioned source)', () async {
      final client = RecordingClient();
      final poster = GithubPrCommentPoster(
        repoSlug: 'arrrrny/zuraffa',
        prNumber: 42,
        token: 'gh-token',
        client: client,
      );

      final ok = await poster.postSnippetSuggestion(
        'Cleanup suggestion:',
        snippetId: ReviewSnippets.tempDirCleanupId,
      );

      expect(ok, isTrue);
      expect(client.sent, hasLength(1));
      final body =
          (jsonDecode(client.sent.single.body) as Map<String, dynamic>)['body']
              as String;
      expect(body, contains('Cleanup suggestion:'));
      expect(body, contains('deleteSync(recursive: true)'));
      expect(body, contains('```dart'));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('postSnippetSuggestion refuses an unknown template id — no '
        'request is sent', () async {
      final client = RecordingClient();
      final poster = GithubPrCommentPoster(
        repoSlug: 'arrrrny/zuraffa',
        prNumber: 42,
        token: 'gh-token',
        client: client,
      );

      final ok = await poster.postSnippetSuggestion(
        'Cleanup suggestion:',
        snippetId: 'no_such_template',
      );

      expect(ok, isFalse);
      expect(client.sent, isEmpty);
    });
  });
}
