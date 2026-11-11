/// Suggestion diff guard (issue #2064): stands between "review comment
/// rendered" and "review comment published" so a ```diff suggestion whose
/// added lines would break a block comment is never posted.
///
/// Issue #2064: `zuraffa-review[bot]`'s inline suggestion on
/// arrrrny/raptorr#504 (review comment 4532260043) proposed a docblock
/// reword whose added lines contain the `**/*.spec.ts` glob — the `*/`
/// inside `**/` closes the enclosing `/** ... */` block comment when the
/// suggestion is applied verbatim, and the remainder of the file is parsed
/// as live code (`error: Unexpected *`). The suggestion generator did not
/// account for the destination context: text destined for inside a block
/// comment must not contain the terminator sequence `*/`.
///
/// The guard is pure string work — no I/O, no analyzer. For every
/// ```diff fenced block in a comment body it separates the removed (`-`)
/// and added (`+`) lines and reconstructs the destination context the diff
/// itself reveals:
///
/// - the target hunk lies inside a block comment when the removed lines
///   are comment-interior lines (docblock body lines — trimmed, they start
///   with `*`), or, for a pure insertion with no removed lines, when every
///   added line is itself comment-interior;
/// - when the target is a block comment, any added line containing the
///   literal `*/` is flagged `comment_terminator_in_suggestion` — applied
///   verbatim it would close the comment early.
///
/// A flagged suggestion is refused at the transport
/// ([GithubPrCommentPoster] runs this scan in its posting gate), matching
/// the issue's remedy: reword so the literal `*/` does not appear (e.g.
/// split the code span around the slash) or flag the suggestion as not
/// directly applicable.
library;

import 'snippet_compile_check.dart';

/// The block-comment safety scan for ```diff suggestion blocks.
abstract final class SuggestionDiffGuard {
  static final RegExp _diffFence = RegExp(
    '```diff[ \t]*\n(.*?)```',
    dotAll: true,
  );

  /// Every ```diff fenced block in [body] (best-effort extraction, the
  /// same fence convention as [SnippetPostingGate]: an unterminated fence
  /// matches nothing).
  static List<String> diffBlocks(String body) =>
      _diffFence.allMatches(body).map((m) => m.group(1)!).toList();

  /// Scans every ```diff block in [body]; one
  /// `comment_terminator_in_suggestion` issue per offending added line.
  /// Empty when there is nothing to scan or every block is safe.
  static List<SnippetValidationIssue> scanBody(String body) {
    final issues = <SnippetValidationIssue>[];
    for (final block in diffBlocks(body)) {
      issues.addAll(scanBlock(block));
    }
    return issues;
  }

  /// Scans one diff block's content (the lines between the fences).
  ///
  /// Hunk headers (`---`/`+++`) and context lines (neither `-` nor `+`)
  /// are ignored — only the removed/added pair carries the destination
  /// signal and the risk.
  static List<SnippetValidationIssue> scanBlock(String diffBlock) {
    final removed = <String>[];
    final added = <String>[];
    for (final rawLine in diffBlock.split('\n')) {
      if (rawLine.startsWith('---') || rawLine.startsWith('+++')) {
        continue; // unified-diff file/hunk headers, not content lines
      }
      if (rawLine.startsWith('-')) {
        removed.add(rawLine.substring(1));
      } else if (rawLine.startsWith('+')) {
        added.add(rawLine.substring(1));
      }
    }

    if (!_targetIsBlockComment(removed: removed, added: added)) {
      return const [];
    }

    final issues = <SnippetValidationIssue>[];
    for (final line in added) {
      if (!line.contains('*/')) continue;
      issues.add(
        SnippetValidationIssue(
          severity: SnippetIssueSeverity.error,
          code: 'comment_terminator_in_suggestion',
          message:
              'the added line `${line.trim()}` contains the terminator '
              'sequence `*/` while the suggestion rewrites a block comment '
              '— applied verbatim it closes the comment early and the '
              'remainder of the file no longer compiles (issue #2064). '
              'Reword so the literal `*/` does not appear (e.g. split the '
              'code span around the slash) or flag the suggestion as not '
              'directly applicable.',
        ),
      );
    }
    return issues;
  }

  /// Reconstructs the destination context from the diff itself: the hunk
  /// rewrites a block comment when its removed lines are all comment
  /// interior (docblock body lines — trimmed, they start with `*`), or —
  /// for a pure insertion with nothing removed — when every added line is
  /// itself comment interior. An empty hunk (no removed or added lines) is
  /// not a comment target.
  static bool _targetIsBlockComment({
    required List<String> removed,
    required List<String> added,
  }) {
    final removedInterior = removed.where((l) => l.trim().isNotEmpty);
    if (removedInterior.isNotEmpty) {
      return removedInterior.every(_isCommentInteriorLine);
    }
    final addedInterior = added.where((l) => l.trim().isNotEmpty);
    return addedInterior.isNotEmpty &&
        addedInterior.every(_isCommentInteriorLine);
  }

  /// A docblock body line: trimmed of leading whitespace it starts with
  /// the `*` continuation marker (e.g. ` * module graph — ...`).
  static bool _isCommentInteriorLine(String line) =>
      line.trimLeft().startsWith('*');
}
