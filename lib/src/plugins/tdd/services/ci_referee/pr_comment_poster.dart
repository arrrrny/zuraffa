/// PR comment posting (spec 070 US1): the sink that delivers the verdict
/// comment to the pull request. Two implementations:
///
/// - [GithubPrCommentPoster] — posts through the GitHub REST API
///   (`POST /repos/<slug>/issues/<n>/comments`) with an injected
///   `http.Client` so tests never touch the network.
/// - [DryRunPrCommentPoster] — renders locally, zero network access.
///
/// Every body a [GithubPrCommentPoster] publishes passes the snippet
/// gate ([SnippetPostingGate], PR #1703 review fix): each ```dart fenced
/// block is validated through the spec-1685 gate (deny-list scan + REAL
/// analyzer compile check) and the comment is refused when a block does
/// not compile — the #1685 misfire class is closed mechanically at the
/// transport, not by caller convention. Code suggestions must be sourced
/// from the validated catalog via [GithubPrCommentPoster.postSnippetSuggestion].
library;

import 'dart:io';

import 'package:http/http.dart' as http;

import 'review_snippets.dart';
import 'snippet_compile_check.dart';

/// The comment sink contract: posts [body], returns whether it landed.
abstract interface class PrCommentPoster {
  Future<bool> postComment(String body);
}

/// The posting-path snippet gate (PR #1703 review fix): every ```dart
/// fenced code block in a body about to be PUBLISHED runs through the
/// spec-1685 validation gate ([SnippetCompileCheck.validate] — deny-list
/// scan, then REAL analyzer resolve). Any error-severity finding — or a
/// gate that cannot run at all — blocks the comment: fail closed.
final class SnippetPostingGate {
  const SnippetPostingGate({this.check = const SnippetCompileCheck()});

  final SnippetCompileCheck check;

  static final RegExp _dartFence = RegExp(
    '```dart[ \t]*\n(.*?)```',
    dotAll: true,
  );

  /// Every ```dart fenced code block in [body] (best-effort extraction:
  /// a suggestion is a fenced block; unterminated fences match nothing).
  List<String> dartBlocks(String body) =>
      _dartFence.allMatches(body).map((m) => m.group(1)!.trimRight()).toList();

  /// The first failing gate render across [body]'s dart blocks, or `null`
  /// when every block is clear (or there are none — no analyzer work).
  Future<String?> blockedReason(String body) async {
    for (final block in dartBlocks(body)) {
      final result = await check.validate(block);
      if (!result.passed) return result.render;
    }
    return null;
  }
}

class GithubPrCommentPoster implements PrCommentPoster {
  GithubPrCommentPoster({
    required this.repoSlug,
    required this.prNumber,
    required this.token,
    http.Client? client,
    SnippetPostingGate? snippetGate,
  }) : _client = client ?? http.Client(),
       snippetGate = snippetGate ?? const SnippetPostingGate();

  /// `owner/name` repository slug.
  final String repoSlug;

  /// The pull request number.
  final int prNumber;

  /// The GitHub token (from the CI environment; never logged).
  final String token;

  /// The snippet gate every published body passes through (fail-closed).
  final SnippetPostingGate snippetGate;

  final http.Client _client;

  static const _successCodes = {200, 201};

  @override
  Future<bool> postComment(String body) async {
    final blocked = await _gateBlockedReason(body);
    if (blocked != null) {
      // Fail CLOSED: an un-compilable suggestion never reaches the PR.
      stderr.writeln(
        'pr_comment_poster: snippet gate blocked the comment — $blocked',
      );
      return false;
    }
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

  /// The gate verdict for [body]: `null` when clear. Fast path — a body
  /// with no dart fence (every verdict comment) never touches the
  /// analyzer. Any gate failure (findings, missing package context)
  /// BLOCKS the post: a transport that publishes through a broken gate
  /// is not gated.
  Future<String?> _gateBlockedReason(String body) async {
    if (!body.contains('```dart')) return null;
    try {
      return await snippetGate.blockedReason(body);
    } on Exception catch (e) {
      return 'gate failed closed: $e';
    } on StateError catch (e) {
      return 'gate failed closed: $e';
    }
  }

  /// The sanctioned way to publish a code suggestion: the snippet comes
  /// from the validated catalog ([ReviewSnippets.postableSnippet]) and
  /// the assembled body still passes [postComment]'s gate — an
  /// improvised template can never enter through here.
  Future<bool> postSnippetSuggestion(
    String body, {
    required String snippetId,
    String directoryVariable = 'tmp',
  }) async {
    final String code;
    try {
      code = await ReviewSnippets.postableSnippet(
        snippetId,
        directoryVariable: directoryVariable,
      );
    } on SnippetValidationException catch (e) {
      stderr.writeln('pr_comment_poster: $e');
      return false;
    } on ArgumentError catch (e) {
      stderr.writeln('pr_comment_poster: $e');
      return false;
    } on StateError catch (e) {
      stderr.writeln('pr_comment_poster: gate failed closed: $e');
      return false;
    }
    return postComment('$body\n\n```dart\n$code\n```\n');
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
