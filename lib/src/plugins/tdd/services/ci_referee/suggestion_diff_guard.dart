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
/// ```diff fenced block in a comment body it:
///
/// - extracts the block the way CommonMark closes a fence: the closing
///   fence occupies its own line (at most three spaces of indent, nothing
///   on the line but backticks and trailing whitespace) and is at least as
///   long as the opening fence — an inline ``` inside a diff line cannot
///   terminate extraction early (PR #2065 review finding);
/// - splits the block at hunk (`@@`) and file (`diff --git`, `---`, `+++`)
///   boundaries and classifies each hunk independently, so a docblock
///   rewrite in one hunk is never cancelled by plain-code removals in
///   another (PR #2065 review finding);
/// - walks each hunk in order tracking the block-comment state: context
///   and removed lines are pre-image content and advance the state, and
///   every added line is checked at the state its position lands in — a
///   comment opened on an earlier unchanged (or removed) line therefore
///   participates, even when the removed lines carry no `*` continuation
///   markers (PR #2065 review finding). When the hunk itself carries no
///   boundary signal the entry state is seeded from line shapes: removed
///   lines that are all comment-interior (`*`- or `/*`-prefixed — the
///   `/*` arm covers hunks that rewrite the docblock's opening line), or,
///   for a pure insertion, added lines that are all comment-interior;
/// - when that state is inside a block comment, an added line that CLOSES
///   the comment with live code left over — a `*/` whose remainder on the
///   line is not whitespace — is flagged
///   `comment_terminator_in_suggestion`: applied verbatim it closes the
///   comment early. A line that ends the comment cleanly (a bare ` */`
///   closer, or a reword whose new text ends with the closer) is allowed,
///   and so is a complete `/** ... */` line that opens and closes its own
///   comment without exposing code.
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
  /// A ```diff fence whose closing fence is a real CommonMark closing
  /// fence: a line of its own, at most three spaces of indent, only
  /// backticks (at least as many as the opener captured in group 1) and
  /// trailing whitespace. An unterminated fence matches nothing, and an
  /// inline ``` mid-line can never close the block.
  static final RegExp _diffFence = RegExp(
    '(`{3,})diff[ \t]*\n(.*?)^ {0,3}\\1`{0,}[ \t]*\$',
    multiLine: true,
    dotAll: true,
  );

  /// Every ```diff fenced block in [body] (best-effort extraction, the
  /// same fence convention as [SnippetPostingGate]: an unterminated fence
  /// matches nothing).
  static List<String> diffBlocks(String body) =>
      _diffFence.allMatches(body).map((m) => m.group(2)!).toList();

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

  /// Scans one diff block's content (the lines between the fences): the
  /// block is split at hunk and file boundaries and each hunk is scanned
  /// independently — the hunks share no classification state.
  static List<SnippetValidationIssue> scanBlock(String diffBlock) {
    final issues = <SnippetValidationIssue>[];
    for (final hunk in _splitHunks(diffBlock)) {
      issues.addAll(_scanHunk(hunk));
    }
    return issues;
  }

  /// A line at which one hunk ends and the next (or the next file) begins.
  static bool _isDiffBoundary(String line) =>
      line.startsWith('@@') ||
      line.startsWith('diff --git') ||
      line.startsWith('---') ||
      line.startsWith('+++');

  /// Splits [diffBlock] at hunk (`@@`) and file (`diff --git`, `---`,
  /// `+++`) boundaries; the boundary lines themselves are dropped. A block
  /// with no boundaries (the GitHub suggestion shape) is one hunk.
  static List<List<String>> _splitHunks(String diffBlock) {
    final hunks = <List<String>>[];
    var current = <String>[];
    for (final line in diffBlock.split('\n')) {
      if (_isDiffBoundary(line)) {
        if (current.isNotEmpty) hunks.add(current);
        current = <String>[];
        continue;
      }
      current.add(line);
    }
    if (current.isNotEmpty) hunks.add(current);
    return hunks;
  }

  /// Walks one hunk's lines in order, carrying the block-comment state:
  /// removed and context lines are the file's pre-image content at their
  /// position and advance the state; each added line is checked at the
  /// state its position lands in (an added line that opens a block comment
  /// is checked as inside one — its own `/*` opener counts) and then
  /// advances the state as the file's post-image content.
  static List<SnippetValidationIssue> _scanHunk(List<String> lines) {
    final removed = <String>[];
    final added = <String>[];
    for (final raw in lines) {
      if (raw.startsWith('-')) {
        removed.add(raw.substring(1));
      } else if (raw.startsWith('+')) {
        added.add(raw.substring(1));
      }
    }

    final issues = <SnippetValidationIssue>[];
    var inComment = _entryState(removed: removed, added: added);
    for (final raw in lines) {
      if (raw.startsWith('-')) {
        inComment = _scanLine(raw.substring(1), inComment).endsInComment;
      } else if (raw.startsWith('+')) {
        final content = raw.substring(1);
        final scan = _scanLine(
          content,
          inComment || _opensBlockComment(content),
        );
        if (scan.closesEarly) {
          issues.add(_terminatorIssue(content));
        }
        inComment = scan.endsInComment;
      } else {
        inComment = _scanLine(raw, inComment).endsInComment;
      }
    }
    return issues;
  }

  /// The state the hunk's walk starts in, seeded from line shapes when the
  /// hunk reveals no boundary of its own: removed lines that are all
  /// comment-interior mean the hunk rewrites a docblock body; a pure
  /// insertion whose added lines are all comment-interior targets the
  /// inside of a block comment the same way. A hunk with no such signal
  /// starts outside a comment and relies on its context lines.
  static bool _entryState({
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
  /// the `*` continuation marker (e.g. ` * module graph — ...`) or the
  /// `/*` opener (e.g. `/** Parses config files.` — a hunk that rewrites
  /// the docblock's first line is a comment target too).
  static bool _isCommentInteriorLine(String line) =>
      line.trimLeft().startsWith('*') || line.trimLeft().startsWith('/*');

  /// Whether [line] opens a block comment right where its text begins —
  /// the shape of an added docblock line, whose mid-line `*/` hazard
  /// exists regardless of the state around the line.
  static bool _opensBlockComment(String line) =>
      line.trimLeft().startsWith('/*');

  /// Scans [line] for comment markers starting in block-comment state
  /// [inComment]. [ScanResult.closesEarly] is set when a `*/` terminates
  /// the comment with non-whitespace text left on the line — applied
  /// verbatim that text is live code. [ScanResult.endsInComment] is the
  /// state after the line. String literals are not tracked (pure string
  /// work, fail-closed direction).
  static _ScanResult _scanLine(String line, bool inComment) {
    var i = 0;
    var closesEarly = false;
    while (i < line.length) {
      if (inComment && line.startsWith('*/', i)) {
        if (line.substring(i + 2).trim().isNotEmpty) closesEarly = true;
        inComment = false;
        i += 2;
      } else if (!inComment && line.startsWith('/*', i)) {
        inComment = true;
        i += 2;
      } else {
        i += 1;
      }
    }
    return _ScanResult(closesEarly: closesEarly, endsInComment: inComment);
  }

  static SnippetValidationIssue _terminatorIssue(String line) =>
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
      );
}

/// One line's comment-marker scan result.
class _ScanResult {
  const _ScanResult({required this.closesEarly, required this.endsInComment});

  /// A `*/` closed the comment with non-whitespace text left on the line.
  final bool closesEarly;

  /// Whether the line leaves the scanner inside a block comment.
  final bool endsInComment;
}
