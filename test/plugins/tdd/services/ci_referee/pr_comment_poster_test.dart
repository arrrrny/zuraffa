// U12-U13 (spec 070): the PR comment poster — posts the verdict comment
// to a pull request through the GitHub API (US1, SC-001), with a
// dry-run sink that renders locally without any network access.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/pr_comment_poster.dart';

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
}
