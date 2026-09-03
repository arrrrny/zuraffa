/// PR comment posting (spec 070 US1): the sink that delivers the verdict
/// comment to the pull request. Two implementations:
///
/// - [GithubPrCommentPoster] — posts through the GitHub REST API
///   (`POST /repos/<slug>/issues/<n>/comments`) with an injected
///   `http.Client` so tests never touch the network.
/// - [DryRunPrCommentPoster] — renders locally, zero network access.
library;

import 'package:http/http.dart' as http;

/// The comment sink contract: posts [body], returns whether it landed.
abstract interface class PrCommentPoster {
  Future<bool> postComment(String body);
}

class GithubPrCommentPoster implements PrCommentPoster {
  GithubPrCommentPoster({
    required this.repoSlug,
    required this.prNumber,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// `owner/name` repository slug.
  final String repoSlug;

  /// The pull request number.
  final int prNumber;

  /// The GitHub token (from the CI environment; never logged).
  final String token;

  final http.Client _client;

  static const _successCodes = {200, 201};

  @override
  Future<bool> postComment(String body) async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$repoSlug/issues/$prNumber/comments',
    );
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github+json',
          'Content-Type': 'application/json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        body: '{"body": ${_jsonEncode(body)}}',
      );
      return _successCodes.contains(response.statusCode);
    } on Exception {
      // Network failures surface as not-posted — the referee never
      // crashes on delivery; CI retries the step on the next run.
      return false;
    }
  }

  static String _jsonEncode(String value) =>
      '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n')}"';
}

class DryRunPrCommentPoster implements PrCommentPoster {
  String? rendered;

  @override
  Future<bool> postComment(String body) async {
    rendered = body;
    return true;
  }
}
